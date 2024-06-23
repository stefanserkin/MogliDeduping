@IsTest
public class FlowReportToCampaignService_Test {
    
    private static final String REPORT_DEVELOPER_NAME = 'Mogli_Deduplication_Test_Report_yOe';
    private static final String FILTERED_TITLE = 'Tester Person';
    private static final String CONTACT_ID_COLUMN_NAME = 'CONTACT_ID';
    private static final String PHONE_NUMBER_COLUMN_NAME = 'PHONE3';

    private static Campaign createCampaign() {
        Campaign campaign = new Campaign(
            Name = 'Test Campaign',
            StartDate = Date.today(),
            EndDate = Date.today().addDays(30),
            Type = 'Email'
        );
        insert campaign;
        return campaign;
    }

    private static List<Contact> createSampleContacts() {
        List<Contact> contacts = new List<Contact>{
            new Contact(MobilePhone = '123-456-7890',FirstName = 'Rey',LastName = 'Ordonez',Title = FILTERED_TITLE),
            new Contact(MobilePhone = '123-456-7890',FirstName = 'Edgardo',LastName = 'Alfonzo',Title = FILTERED_TITLE),
            new Contact(MobilePhone = '987-654-3210',FirstName = 'Jon',LastName = 'Olerud',Title = FILTERED_TITLE),
            new Contact(FirstName = 'No',LastName = 'Phone',Title = FILTERED_TITLE)
        };
        insert contacts;
        return contacts;
    }

    @IsTest(SeeAllData='true')
    static void testGetUniqueCampaignMembers() {
        Campaign campaign = createCampaign();
        createSampleContacts();

        Id reportId = getReportId(REPORT_DEVELOPER_NAME);

        FlowReportToCampaignService.Request request = new FlowReportToCampaignService.Request();
        request.reportId = reportId;
        request.campaignId = campaign.Id;
        request.contactPhoneField = 'MobilePhone';
        request.contactIdColumn = CONTACT_ID_COLUMN_NAME;
        request.phoneNumberColumn = PHONE_NUMBER_COLUMN_NAME;

        List<FlowReportToCampaignService.Request> requests = new List<FlowReportToCampaignService.Request>{request};

        Test.startTest();
        List<FlowReportToCampaignService.Result> results = FlowReportToCampaignService.getUniqueCampaignMembers(requests);
        Test.stopTest();

        Assert.isFalse(results.isEmpty(), 'Results should not be empty');
        FlowReportToCampaignService.Result result = results[0];
        Assert.areEqual(2, result.campaignMembers.size(), 'There should be 1 unique campaign member excluding existing ones');
    }

    @IsTest(SeeAllData='true')
    static void testNoDuplicatesInExistingCampaign() {
        Campaign campaign = createCampaign();
        createSampleContacts();

        Contact contact = [SELECT Id FROM Contact WHERE LastName = 'Alfonzo' LIMIT 1];

        // Add only one contact with duplicate number to the campaign as an existing member
        CampaignMember existingMember = new CampaignMember(
            ContactId = contact.Id,
            CampaignId = campaign.Id
        );
        insert existingMember;

        Id reportId = getReportId(REPORT_DEVELOPER_NAME);

        FlowReportToCampaignService.Request request = new FlowReportToCampaignService.Request();
        request.reportId = reportId;
        request.campaignId = campaign.Id;
        request.contactIdColumn = CONTACT_ID_COLUMN_NAME;
        request.phoneNumberColumn = PHONE_NUMBER_COLUMN_NAME;

        List<FlowReportToCampaignService.Request> requests = new List<FlowReportToCampaignService.Request>{request};

        Test.startTest();
        List<FlowReportToCampaignService.Result> results = FlowReportToCampaignService.getUniqueCampaignMembers(requests);
        Test.stopTest();

        Assert.isFalse(results.isEmpty(), 'Results should not be empty');
        FlowReportToCampaignService.Result result = results[0];
        Assert.areEqual(1, result.campaignMembers.size(), 'There should be 1 unique campaign member excluding existing ones');
    }

    @IsTest(SeeAllData='true')
    static void testMultipleReportRuns() {
        Campaign campaign = createCampaign();
        createSampleContacts();

        Id reportId = getReportId(REPORT_DEVELOPER_NAME);

        FlowReportToCampaignService.Request request = new FlowReportToCampaignService.Request();
        request.reportId = reportId;
        request.campaignId = campaign.Id;
        request.contactIdColumn = CONTACT_ID_COLUMN_NAME;
        request.phoneNumberColumn = PHONE_NUMBER_COLUMN_NAME;

        // Run report a first time to produce report results and create csv of contact ids to filter out
        Reports.ReportResults reportResults = Reports.ReportManager.runReport(reportId, true);
        Reports.ReportFactWithDetails facts = (Reports.ReportFactWithDetails) reportResults.getFactMap().get('T!T');
        String contactIds = '';
        for (Reports.ReportDetailRow row : facts.getRows()) {
            contactIds += String.valueOf(row.getDataCells()[0].getLabel()) + ',';
        }
        contactIds = contactIds.removeEnd(',');

        Test.startTest();
        Reports.ReportResults newResults = FlowReportToCampaignService.runReport(request, reportResults, contactIds);
        Test.stopTest();

        Assert.isFalse(newResults.getReportMetadata().getReportFilters().isEmpty(), 'Report filters should not be empty');
        
        Reports.ReportFactWithDetails factWithDetails = (Reports.ReportFactWithDetails) newResults.getFactMap().get('T!T');
        Assert.isTrue(factWithDetails.getRows().isEmpty(), 'Should not have received any more rows');
    }

    @IsTest(SeeAllData='true')
    static void testPaginatedReportResults() {
        createCampaign();
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 4001; i++) {
            contacts.add(new Contact(
                FirstName = 'Jon' + String.valueOf(i),
                LastName = 'Olerud' + String.valueOf(i),
                MobilePhone = '555' + String.valueOf(i).leftPad(7, '0'),
                Title = FILTERED_TITLE
            ));
        }
        insert contacts;

        Campaign campaign = [SELECT Id FROM Campaign LIMIT 1];

        Id reportId = getReportId(REPORT_DEVELOPER_NAME);

        FlowReportToCampaignService.Request request = new FlowReportToCampaignService.Request();
        request.reportId = reportId;
        request.campaignId = campaign.Id;
        request.contactIdColumn = CONTACT_ID_COLUMN_NAME;
        request.phoneNumberColumn = PHONE_NUMBER_COLUMN_NAME;

        List<FlowReportToCampaignService.Request> requests = new List<FlowReportToCampaignService.Request>{request};

        Test.startTest();
        List<FlowReportToCampaignService.Result> results = FlowReportToCampaignService.getUniqueCampaignMembers(requests);
        Test.stopTest();

        Assert.isFalse(results.isEmpty(), 'Results should not be empty');
        FlowReportToCampaignService.Result result = results[0];
        Assert.areEqual(4001, result.campaignMembers.size(), 'There should be 4001 unique campaign members');
    }

    @IsTest
    static void testRequestWithException() {
        String invalidField = 'Invalid_Field';

        FlowReportToCampaignService.Request request = new FlowReportToCampaignService.Request();
        request.reportId = getReportId(REPORT_DEVELOPER_NAME);
        request.campaignId = createCampaign().Id;
        request.contactIdColumn = CONTACT_ID_COLUMN_NAME;
        request.phoneNumberColumn = PHONE_NUMBER_COLUMN_NAME;
        request.contactPhoneField = invalidField;

        List<FlowReportToCampaignService.Result> results;
        Test.startTest();
        try {
            results = FlowReportToCampaignService.getUniqueCampaignMembers(
                new List<FlowReportToCampaignService.Request>{ request }
            );
            Assert.fail('Should not have received results with the invalid field name');
        } catch (Exception e) {
            Assert.isTrue(e.getMessage().contains('No such column'), 'Should throw an exception for the invalid contact field');
            Assert.areEqual('FlowReportToCampaignService.ReportToCampaignServiceException', e.getTypeName(), 'Should have received the service custom exception');
        }
    }

    private static Id getReportId(String reportDeveloperName) {
        List<Report> reportList = [SELECT Id FROM Report WHERE DeveloperName = :reportDeveloperName LIMIT 1];
        if (reportList.isEmpty()) {
            return null;
        }
        return reportList[0].Id;
    }

}