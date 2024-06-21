/**
 * @date 2024
 */
public with sharing class FlowReportToCampaignService {

    @InvocableMethod(
        label='Add Contacts with Unique Mobile Numbers to Campaign' 
        description='Retrieve report data, deduplicate contacts based on phone numbers, and add them to a campaign.'
    )
    public static List<Result> addUniqueContactsToCampaign(
        List<Request> requests
    ) {
        List<Result> lstResults = new List<Result>();
        try {
            for (Request request : requests) {
                List<Contact> uniqueContacts = getUniqueContactsFromReport(request.reportId, request.campaignId);
                List<CampaignMember> campaignMembers = addContactsToCampaign(uniqueContacts, request.campaignId);

                Result result = new Result();
                result.campaignMembers = campaignMembers;
                lstResults.add(result);
            } 
        } catch (Exception e) {
            System.debug('Failed to add contacts to campaign: ' + e.getMessage());
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
    private static List<Contact> getUniqueContactsFromReport(
        Id reportId, 
        Id campaignId
    ) {
        Map<String, Contact> uniqueContactsMap = new Map<String, Contact>();
        Set<String> setExistingCampaignNumbers = getExistingCampaignNumbers(campaignId);

        // Track batch sizes for pagination
        Integer lastBatchSize;
        Reports.ReportResults reportResults;
        String retrievedContactIdCsv = '';

        do {
            reportResults = runReport(reportId, reportResults, retrievedContactIdCsv);
            Reports.ReportFactWithDetails factWithDetails = (Reports.ReportFactWithDetails) reportResults.getFactMap().get('T!T');

            Set<Id> contactIds = new Set<Id>();
            for (Reports.ReportDetailRow row : factWithDetails.getRows()) {
                Id contactId = (Id) row.getDataCells()[0].getLabel();
                contactIds.add(contactId);

                // Guard against blank mobile numbers and those already included for existing campaign members
                String mobilePhone = (String) row.getDataCells()[1].getLabel();
                if (String.isBlank(mobilePhone) || mobilePhone == '-') {
                    continue;
                }
                String standardizedPhone = standardizePhoneNumber(mobilePhone);
                if (setExistingCampaignNumbers.contains(standardizedPhone)) {
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
            reportResults = Reports.ReportManager.runReport(reportId, true);
        } else {
            // For subsequent runs, contact ids retrieved in previous runs are excluded to create pagination
            Reports.ReportMetadata reportMetadata = reportResults.getReportMetadata();
            Reports.ReportFilter reportFilter = reportMetadata.getReportFilters()[0];
            reportFilter.setOperator('notEqual');
            reportFilter.setValue(contactIdsToFilter);
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
    private static List<CampaignMember> addContactsToCampaign(
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

    /**
     * Get existing campaign members to protect against duplicates with existing mobile numbers
     * @param campaignId Id of campaign
     * @return Set<String> Mobile numbers of existing campaign members
     */
    private static Set<String> getExistingCampaignNumbers(
        Id campaignId
    ) {
        Set<String> existingMobileNumbers = new Set<String>();
        for (CampaignMember cm : [SELECT Contact.MobilePhone 
                                    FROM CampaignMember 
                                   WHERE CampaignId = :campaignId
                                    WITH SYSTEM_MODE]
        ) {
            existingMobileNumbers.add(standardizePhoneNumber(cm.Contact.MobilePhone));
        }
        return existingMobileNumbers;
    }

    /**
     * Standardize phone numbers to check for duplicates with varying formatting
     * @param phone Phone number to standardize
     * @return String Standardized phone number
     */
    private static String standardizePhoneNumber(String phone) {
        return phone != null ? phone.replaceAll('[^0-9]', '') : null;
    }

    public class Request {
        @InvocableVariable(label='Report Id' required=true)
        public Id reportId;
        @InvocableVariable(label='Campaign Id' required=true)
        public Id campaignId;
    }

    public class Result {
        @InvocableVariable(label='Campaign Members')
        public List<CampaignMember> campaignMembers;
    }

}
