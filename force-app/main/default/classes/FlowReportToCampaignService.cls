/**
 * @date 2024
 */
public with sharing class FlowReportToCampaignService {

    @InvocableMethod(
        label='Add Contacts with Unique Mobile Numbers to Campaign' 
        description='Retrieve report data, deduplicate contacts based on phone numbers, and add them to a campaign.'
    )
    public static List<Result> addUniqueContactsToCampaign(List<Request> requests) {
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
     */
    private static List<Contact> getUniqueContactsFromReport(Id reportId, Id campaignId) {
        Map<String, Contact> uniqueContactsMap = new Map<String, Contact>();
        Set<String> setExistingCampaignNumbers = getExistingCampaignNumbers(campaignId);

        Reports.ReportResults reportResults = Reports.ReportManager.runReport(reportId, true);
        Reports.ReportFactWithDetails factWithDetails = (Reports.ReportFactWithDetails) reportResults.getFactMap().get('T!T');

        for (Reports.ReportDetailRow row : factWithDetails.getRows()) {
            // Assumption: Mobile phone is in the second column
            String mobilePhone = (String) row.getDataCells()[1].getLabel();
            // Standardize the phone number
            String standardizedPhone = standardizePhoneNumber(mobilePhone);

            // Guard against duplicates from existing campaign members
            if (setExistingCampaignNumbers.contains(standardizedPhone)) 
                continue;

            Contact contact = new Contact();
            // Assumption: Contact Id is in the first column
            contact.Id = (Id) row.getDataCells()[0].getLabel();
            contact.MobilePhone = mobilePhone;
            uniqueContactsMap.put(standardizedPhone, contact);
        }

        return uniqueContactsMap.values();
    }

    /**
     * Add contacts to a campaign
     * @param contacts List of contacts to add to the campaign
     * @param campaignId Id of campaign to add the contacts to
     */
    private static List<CampaignMember> addContactsToCampaign(List<Contact> contacts, Id campaignId) {
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
     */
    private static Set<String> getExistingCampaignNumbers(Id campaignId) {
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
