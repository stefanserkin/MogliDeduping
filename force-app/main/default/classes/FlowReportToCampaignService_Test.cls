@IsTest
public class FlowReportToCampaignService_Test {
    
    private static final String REPORT_DEVELOPER_NAME = 'Mogli_Deduplication_Test_Report_yOe';
    private static final String FILTERED_TITLE = 'Tester Person';

    private static void makeData() {
        // Setup campaign
        Campaign testCampaign = new Campaign(
            Name = 'Test Campaign',
            StartDate = Date.today(),
            EndDate = Date.today().addDays(30),
            Type = 'Email'
        );
        insert testCampaign;

        // Create test contacts
        Contact contact1 = new Contact(
            FirstName = 'Rey',
            LastName = 'Ordonez',
            MobilePhone = '123-456-7890',
            Title = FILTERED_TITLE
        );
        Contact contact2 = new Contact(
            FirstName = 'Edgardo',
            LastName = 'Alfonzo',
            MobilePhone = '123-456-7890',
            Title = FILTERED_TITLE
        );
        Contact contact3 = new Contact(
            FirstName = 'Jon',
            LastName = 'Olerud',
            MobilePhone = '987-654-3210',
            Title = FILTERED_TITLE
        );
        insert new List<Contact>{contact1, contact2, contact3};
    }

    @IsTest(SeeAllData='true')
    static void testAddUniqueContactsToCampaign() {
        makeData();

        Campaign campaign = [SELECT Id FROM Campaign LIMIT 1];

        Id reportId = getReportId(REPORT_DEVELOPER_NAME);

        FlowReportToCampaignService.Request request = new FlowReportToCampaignService.Request();
        request.reportId = reportId;
        request.campaignId = campaign.Id;

        List<FlowReportToCampaignService.Request> requests = new List<FlowReportToCampaignService.Request>{request};

        Test.startTest();
        List<FlowReportToCampaignService.Result> results = FlowReportToCampaignService.addUniqueContactsToCampaign(requests);
        Test.stopTest();

        Assert.isFalse(results.isEmpty(), 'Results should not be empty');
        FlowReportToCampaignService.Result result = results[0];
        Assert.areEqual(2, result.campaignMembers.size(), 'There should be 1 unique campaign member excluding existing ones');
    }

    @IsTest(SeeAllData='true')
    static void testNoDuplicatesInExistingCampaign() {
        makeData();

        Campaign campaign = [SELECT Id FROM Campaign LIMIT 1];
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

        List<FlowReportToCampaignService.Request> requests = new List<FlowReportToCampaignService.Request>{request};

        Test.startTest();
        List<FlowReportToCampaignService.Result> results = FlowReportToCampaignService.addUniqueContactsToCampaign(requests);
        Test.stopTest();

        Assert.isFalse(results.isEmpty(), 'Results should not be empty');
        FlowReportToCampaignService.Result result = results[0];
        Assert.areEqual(1, result.campaignMembers.size(), 'There should be 1 unique campaign member excluding existing ones');
    }

    @IsTest(SeeAllData='true')
    static void testMultipleReportRuns() {
        makeData();

        // Run report a first time to produce report results and create csv of contact ids to filter out
        Id reportId = getReportId(REPORT_DEVELOPER_NAME);
        Reports.ReportResults reportResults = Reports.ReportManager.runReport(reportId, true);
        Reports.ReportFactWithDetails facts = (Reports.ReportFactWithDetails) reportResults.getFactMap().get('T!T');
        String contactIds = '';
        for (Reports.ReportDetailRow row : facts.getRows()) {
            contactIds += String.valueOf(row.getDataCells()[0].getLabel()) + ',';
        }
        contactIds = contactIds.removeEnd(',');

        Test.startTest();
        Reports.ReportResults newResults = FlowReportToCampaignService.runReport(reportId, reportResults, contactIds);
        Test.stopTest();

        Assert.isFalse(newResults.getReportMetadata().getReportFilters().isEmpty(), 'Report filters should not be empty');
        
        Reports.ReportFactWithDetails factWithDetails = (Reports.ReportFactWithDetails) newResults.getFactMap().get('T!T');
        Assert.isTrue(factWithDetails.getRows().isEmpty(), 'Should not have received any more rows');
    }

    @IsTest(SeeAllData='true')
    static void testPaginatedReportResults() {
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

        List<FlowReportToCampaignService.Request> requests = new List<FlowReportToCampaignService.Request>{request};

        Test.startTest();
        List<FlowReportToCampaignService.Result> results = FlowReportToCampaignService.addUniqueContactsToCampaign(requests);
        Test.stopTest();

        Assert.isFalse(results.isEmpty(), 'Results should not be empty');
        FlowReportToCampaignService.Result result = results[0];
        Assert.areEqual(4001, result.campaignMembers.size(), 'There should be 4001 unique campaign members');
    }

    private static Id getReportId(String reportDeveloperName) {
        List<Report> reportList = [SELECT Id FROM Report WHERE DeveloperName = :reportDeveloperName LIMIT 1];
        if (reportList.isEmpty()) {
            return null;
        }
        return reportList[0].Id;
    }

}