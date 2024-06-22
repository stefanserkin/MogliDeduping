public with sharing class CampaignMemberReportService {

    public class CampaignMemberReportServiceException extends Exception {}

    private static final String OPERATOR_NOT_EQUAL = 'notEqual';
    private static final String NON_NUMBERS = '[^0-9]';
    private static final String NUMBERS_ONLY = '\\d+';
    private static final String DATATYPE_EMAIL = 'Email';
    private static final String DATATYPE_PHONE = 'Phone';

    private List<CampaignMember> campaignMembers;

    private Reports.ReportMetadata reportMetadata;
    private Reports.ReportExtendedMetadata reportExtendedMetadata;

    private Id campaignId;
    private Id reportId;
    private String contactIdColumn;
    private String uniqueKeyColumn;
    private String mappedContactField;
    private String uniqueKeyDataType;

    public CampaignMemberReportService(CampaignMemberReportRequest request) {
        this.campaignId = request.campaignId;
        System.debug('::: set campaign id --> ' + request.campaignId);
        this.reportId = request.reportId;
        this.contactIdColumn = request.contactIdColumn;
        this.uniqueKeyColumn = request.uniqueKeyColumn;
        this.mappedContactField = request.mappedContactField;
        this.uniqueKeyDataType = request.uniqueKeyDataType;
    }

    public List<CampaignMember> getCampaignMembers() {
        campaignMembers = new List<CampaignMember>();
        System.debug('::: initialized campaign members');
        List<Contact> contacts = getUniqueContactsFromReport();
        System.debug('::: got ' + contacts.size() + ' unique contacts from report');
        for (Contact contact : contacts) {
            CampaignMember member = new CampaignMember(
                CampaignId = campaignId,
                ContactId = contact.Id
            );
            campaignMembers.add(member);
        }
        return campaignMembers;
    }

    /**
     * Get unique contacts from a report
     * Assumptions: The first column of the report is the Contact ID and the second column is the Mobile Number
     * @param reportId ID of report to retrieve
     * @return List<Contact> Unique contacts from report, deduplicated by mobile number
     * @see https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_analytics_report_data.htm
     * @see https://glazeforce.wordpress.com/2016/03/29/workaround-to-2000-record-limits-in-report-analytics-api-salesforce/
     */
    private List<Contact> getUniqueContactsFromReport() {
        Map<String, Contact> uniqueContactsMap = new Map<String, Contact>();
        Set<String> existingCampaignKeys = getExistingCampaignUniqueKeys();
        System.debug('::: existing campaign keys --> ' + existingCampaignKeys);
        List<String> detailColumns = getReportMetadata().getDetailColumns();
        System.debug('::: detail cols --> ' + detailColumns);

        // Track batch sizes for pagination
        Integer lastBatchSize;
        Reports.ReportResults reportResults;
        String retrievedContactIdCsv = '';

        do {
            reportResults = runReport(reportResults, retrievedContactIdCsv);
            Reports.ReportFactWithDetails factWithDetails = (Reports.ReportFactWithDetails) reportResults.getFactMap().get('T!T');

            Set<Id> contactIds = new Set<Id>();
            for (Reports.ReportDetailRow row : factWithDetails.getRows()) {
                Integer contactIdIndex = detailColumns.indexOf(contactIdColumn);
                Integer uniqueKeyIndex = detailColumns.indexOf(uniqueKeyColumn);

                Id contactId = (Id) row.getDataCells()[contactIdIndex].getLabel();
                contactIds.add(contactId);

                String uniqueKey = (String) row.getDataCells()[uniqueKeyIndex].getLabel();
                if (String.isBlank(uniqueKey) || uniqueKey == '-') {
                    continue;
                }
                // Identify type of unique key field
                if (uniqueKeyDataType == DATATYPE_PHONE) {
                    uniqueKey = standardizePhoneNumber(uniqueKey);
                }

                if (existingCampaignKeys.contains(uniqueKey)) {
                    continue;
                }
    
                Contact contact = new Contact(Id = contactId);
                contact.put(mappedContactField, uniqueKey);
                uniqueContactsMap.put(uniqueKey, contact);
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
    private Reports.ReportResults runReport(
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
            Reports.ReportFilter contactIdFilter = new Reports.ReportFilter(
                contactIdColumn, 
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
     * Add contacts to a campaign
     * @param contacts List of contacts to add to the campaign
     * @param campaignId Id of campaign to add the contacts to
     * @return List<CampaignMember> Committed campaign member records
     */
    /*
    private static List<CampaignMember> insertCampaignMembers(
        List<Contact> contacts, 
        Id campaignId
    ) {
        List<CampaignMember> campaignMembers = new List<CampaignMember>();
        // Ensure we don't go over dml limit for transaction
        Integer maxContactsToAdd = contacts.size() <= 10000 ? contacts.size() : 10000;
        for (Integer i = 0; i < maxContactsToAdd; i++) {
            campaignMembers.add(
                new CampaignMember(
                    ContactId = contacts[i].Id,
                    CampaignId = campaignId
                )
            );
        }
        Database.insert(campaignMembers, AccessLevel.USER_MODE);
        return campaignMembers;
    }
        */

    private Set<String> getExistingCampaignUniqueKeys() {
        String pathToContactField = 'Contact.' + mappedContactField;
        System.debug('path --> ' + pathToContactField);
        System.debug(':: campaign id --> ' + campaignId);
        System.debug(':: THIS campaign id --> ' + this.campaignId);
        String query = 'SELECT ' + pathToContactField + ' FROM CampaignMember WHERE CampaignId = :campaignId WITH SYSTEM_MODE';
        System.debug('::: query --> ' + query);
        List<CampaignMember> members = Database.query( String.escapeSingleQuotes(query) );
        System.debug(':::: num members found --> ' + members.size());

        Set<String> setUniqueKeys = new Set<String>();
        for (CampaignMember cm : members) {
            String uKey = (String) cm.getSobject('Contact').get(mappedContactField);
            System.debug(':::: uKey --> ' + uKey);
            if (uniqueKeyDataType == DATATYPE_PHONE) {
                uKey = standardizePhoneNumber(uKey);
            }
            setUniqueKeys.add(uKey);
        }
        return setUniqueKeys;
    }

    private Reports.ReportMetadata getReportMetadata() {
        if (reportMetadata == null) {
            Reports.ReportResults results = Reports.ReportManager.runReport(reportId);
            this.reportMetadata = results.getReportMetadata();
        }
        return this.reportMetadata;
    }

     /**
     * Append a newly added filter to filter logic
     *      1 OR 2 => (1 OR 2) AND 3
     *      1 AND (2 OR 3) => (1 AND (2 OR 3)) AND 4
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
     * Standardize phone numbers to check for duplicates with varying formatting
     * @param phone Phone number to standardize
     * @return String Standardized phone number
     */
    private static String standardizePhoneNumber(String phone) {
        return phone != null ? phone.replaceAll(NON_NUMBERS, '') : null;
    }

}