/**
 * @date 2024
 */
public with sharing class FlowReportToCampaignService {

    public class ReportToCampaignServiceException extends Exception {}

    private static final String OPERATOR_NOT_EQUAL = 'notEqual';
    private static final String NON_NUMBERS = '[^0-9]';
    private static final String NUMBERS_ONLY = '\\d+';

    @InvocableMethod(
        label='Add Contacts with Unique Mobile Numbers to Campaign' 
        description='Retrieve report data, deduplicate contacts based on phone numbers, and add them to a campaign.'
    )
    public static List<Result> findUniqueContacts(
        List<Request> requests
    ) {
        List<Result> lstResults = new List<Result>();
        try {
            for (Request request : requests) {
                List<Contact> uniqueContacts = getUniqueContactsFromReport(request);

                List<CampaignMember> campaignMembers = new List<CampaignMember>();
                for (Contact ct : uniqueContacts) {
                    campaignMembers.add(
                        new CampaignMember(
                            CampaignId = request.campaignId, 
                            ContactId = ct.Id
                        )
                    );
                }

                Result result = new Result();
                result.campaignMembers = campaignMembers;
                lstResults.add(result);
            }
        } catch (Exception e) {
            System.debug('Failed to add contacts to campaign: ' + e.getMessage());
            throw new ReportToCampaignServiceException(e.getMessage());
        }
        return lstResults;
    }

    /**
     * Get unique contacts from a report
     * Assumptions: The first column of the report is the Contact ID and the second column is the Mobile Number
     * @param reportId ID of report to retrieve
     * @return List<Contact> Unique contacts from report, deduplicated by mobile number
     * @see https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_analytics_report_data.htm
     * @see https://glazeforce.wordpress.com/2016/03/29/workaround-to-2000-record-limits-in-report-analytics-api-salesforce/
     */
    private static List<Contact> getUniqueContactsFromReport(Request request) {
        request.contactPhoneField = request.contactPhoneField ?? 'MobilePhone';

        Map<String, Contact> uniqueContactsMap = new Map<String, Contact>();
        List<Set<String>> existingCampaignMemberKeys = getExistingCampaignMemberInfo(
            request.campaignId, 
            request.contactPhoneField
        );
        Set<String> existingContactIds = existingCampaignMemberKeys[0];
        Set<String> existingPhoneNumbers = existingCampaignMemberKeys[1];

        Reports.ReportResults results = Reports.ReportManager.runReport(request.reportId);
        List<String> detailColumns = results.getReportMetadata().getDetailColumns();

        // Track batch sizes for pagination
        Integer lastBatchSize;
        Reports.ReportResults reportResults;
        String retrievedContactIdCsv = '';

        do {
            reportResults = runReport(request.reportId, reportResults, retrievedContactIdCsv);
            Reports.ReportFactWithDetails factWithDetails = (Reports.ReportFactWithDetails) reportResults.getFactMap().get('T!T');

            Set<Id> contactIds = new Set<Id>();
            for (Reports.ReportDetailRow row : factWithDetails.getRows()) {
                Integer contactIdIndex = detailColumns.indexOf(request.contactIdColumn);
                Integer phoneNumberIndex = detailColumns.indexOf(request.phoneNumberColumn);

                Id contactId = (Id) row.getDataCells()[contactIdIndex].getLabel();
                contactIds.add(contactId);
                String mobilePhone = (String) row.getDataCells()[phoneNumberIndex].getLabel();
                String standardizedPhone = standardizePhoneNumber(mobilePhone);

                // Guard against existing members and blank mobile numbers
                if (
                    existingContactIds.contains(contactId) ||
                    existingPhoneNumbers.contains(standardizedPhone) ||
                    String.isBlank(mobilePhone) || 
                    mobilePhone == '-'
                ) {
                    continue;
                }
    
                Contact contact = new Contact();
                contact.Id = contactId;
                contact.MobilePhone = mobilePhone;
                uniqueContactsMap.put(standardizedPhone, contact);
            }

            lastBatchSize = factWithDetails.getRows().size();
            // If the batch size is equal to 2000, add the contact ids to filter out of the next run
            if (lastBatchSize == 2000) {
                if (!String.isBlank(retrievedContactIdCsv)) {
                    retrievedContactIdCsv += ',';
                }
                List<Id> idList = new List<Id>();
                idList.addAll(contactIds);
                retrievedContactIdCsv += String.join(idList, ',');
            }
        } while (lastBatchSize == 2000);

        return uniqueContactsMap.values();
    }

    /**
     * Get report results. 
     * For subsequent runs, contact ids retrieved in previous runs are excluded to create pagination.
     * @param reportId Id of report to retrieve
     * @param reportResults Pass in the reportResults of a previous run to retrieve the next batch.
     * @param retrievedContactIdCsv Pass in a csv of retrieved contact ids to be filtered out of the next run.
     * @return Reports.ReportResults
     */
    @TestVisible
    private static Reports.ReportResults runReport(
        String reportId, 
        Reports.ReportResults reportResults, 
        String contactIdsToFilter
    ) {
        if (reportResults == null) {
            // First run
            reportResults = Reports.ReportManager.runReport(reportId, true);
        } else {
            Reports.ReportMetadata reportMetadata = reportResults.getReportMetadata();
            // Reconstruct filters with original filters + omitted contact ids
            List<Reports.ReportFilter> filters = new List<Reports.ReportFilter>();
            filters.addAll(reportMetadata.getReportFilters());
            // Get first column of report, which must reference the contact id field
            String firstColumnName = reportMetadata.getDetailColumns()[0];
            Reports.ReportFilter contactIdFilter = new Reports.ReportFilter(
                firstColumnName, 
                OPERATOR_NOT_EQUAL, 
                contactIdsToFilter
            );
            filters.add(contactIdFilter);
            reportMetadata.setReportFilters(filters);
            // Preserve filter logic while adding the new filter on contact ids
            String filterLogic = reportMetadata.getReportBooleanFilter();
            if (filterLogic != null) {
                reportMetadata.setReportBooleanFilter( getUpdatedFilterLogic(filterLogic) );
            }
            // Run report
            reportResults = Reports.ReportManager.runReport(reportId, reportMetadata, true);
        }
        return reportResults;
    }

    /**
     * Append a newly added filter to filter logic
     *   1 OR 2 => (1 OR 2) AND 3
     *   1 AND (2 OR 3) => (1 AND (2 OR 3)) AND 4
     * @param originalFilter Previous filter logic
     * @return String Updated filter logic
     */
    private static String getUpdatedFilterLogic(
        String originalFilter
    ) {
        Pattern numberPattern = Pattern.compile(NUMBERS_ONLY);
        Matcher matcher = numberPattern.matcher(originalFilter);
        // Get unique numbers and order them
        Set<Integer> numbers = new Set<Integer>();
        while (matcher.find()) {
            numbers.add(Integer.valueOf(matcher.group()));
        }
        List<Integer> orderedNumbers = new List<Integer>(numbers);
        orderedNumbers.sort();
        // Increment the highest number by 1
        Integer newNumber = orderedNumbers[orderedNumbers.size() - 1] + 1;
        return '(' + originalFilter + ') AND ' + newNumber;
    }

    /**
     * Get existing campaign members to protect against duplicates with existing mobile numbers
     * @param campaignId Id of campaign
     * @param contactPhoneField The api name of the field on the contact to match against
     * @return List<Set<String>> A list of sets of keys for existing campaign members
     *  [0] Contact ids
     *  [1] Standardized phone numbers
     */
    private static List<Set<String>> getExistingCampaignMemberInfo(
        Id campaignId, 
        String contactPhoneField
    ) {
        List<Set<String>> results = new List<Set<String>>();
        Set<String> contactIds = new Set<String>();
        Set<String> phoneNumbers = new Set<String>();

        String pathToContactField = 'Contact.' + contactPhoneField;
        String query = 'SELECT ContactId, ' + String.escapeSingleQuotes(pathToContactField) + 
                       ' FROM CampaignMember WHERE CampaignId = :campaignId AND ContactId != null WITH SYSTEM_MODE';
        List<CampaignMember> members = Database.query(query);

        Set<String> existingMobileNumbers = new Set<String>();
        for (CampaignMember cm : members) {
            contactIds.add(cm.ContactId);
            String phone = (String) cm.getSobject('Contact').get(contactPhoneField);
            phoneNumbers.add( standardizePhoneNumber(phone) );
        }
        results.add(contactIds);
        results.add(phoneNumbers);
        return results;
    }

    /**
     * Standardize phone numbers to check for duplicates with varying formatting
     * @param phone Phone number to standardize
     * @return String Standardized phone number
     */
    private static String standardizePhoneNumber(String phone) {
        return phone != null ? phone.replaceAll(NON_NUMBERS, '') : null;
    }

    public class Request {
        @InvocableVariable(label='Report Id' required=true)
        public Id reportId;
        @InvocableVariable(label='Campaign Id' required=true)
        public Id campaignId;
        @InvocableVariable(label='Contact ID Report Column' required=true)
        public String contactIdColumn;
        @InvocableVariable(label='Phone Number Report Column' required=true)
        public String phoneNumberColumn;
        @InvocableVariable(label='Contact Phone Field for Matching')
        public String contactPhoneField;
    }

    public class Result {
        @InvocableVariable(label='Campaign Members')
        public List<CampaignMember> campaignMembers;
    }

}
