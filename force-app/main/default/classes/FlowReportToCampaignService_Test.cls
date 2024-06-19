@isTest
public class FlowReportToCampaignService_Test {
    
    private static final String REPORT_DEVELOPER_NAME = 'Mogli_Deduplication_Test_Report_yOe';
    private static final String FILTERED_TITLE = 'Tester Person';

    @isTest(SeeAllData='true')
    static void testAddUniqueContactsToCampaign() {
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

        // Retrieve the report ID
        Id reportId = getReportId(REPORT_DEVELOPER_NAME);

        // Create the request for the invocable method
        FlowReportToCampaignService.Request request = new FlowReportToCampaignService.Request();
        request.reportId = reportId;
        request.campaignId = testCampaign.Id;

        List<FlowReportToCampaignService.Request> requests = new List<FlowReportToCampaignService.Request>{request};

        // Call the invocable method
        Test.startTest();
        List<FlowReportToCampaignService.Result> results = FlowReportToCampaignService.addUniqueContactsToCampaign(requests);
        Test.stopTest();

        // Verify the results
        Assert.isFalse(results.isEmpty(), 'Results should not be empty');
        FlowReportToCampaignService.Result result = results[0];
        Assert.areEqual(2, result.campaignMembers.size(), 'There should be 1 unique campaign member excluding existing ones');
    }

    @isTest(SeeAllData='true')
    static void testNoDuplicatesInExistingCampaign() {
        // Setup campaign
        Campaign testCampaignWithExistingMembers = new Campaign(
            Name = 'Test Campaign with Existing Members',
            StartDate = Date.today(),
            EndDate = Date.today().addDays(30),
            Type = 'Email'
        );
        insert testCampaignWithExistingMembers;

        // Create contacts
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

        // Add first contact to the campaign as an existing member
        CampaignMember existingMember = new CampaignMember(
            ContactId = contact1.Id,
            CampaignId = testCampaignWithExistingMembers.Id
        );
        insert existingMember;

        // Retrieve the report ID
        Id reportId = getReportId(REPORT_DEVELOPER_NAME);

        // Create the request for the invocable method
        FlowReportToCampaignService.Request request = new FlowReportToCampaignService.Request();
        request.reportId = reportId;
        request.campaignId = testCampaignWithExistingMembers.Id;

        List<FlowReportToCampaignService.Request> requests = new List<FlowReportToCampaignService.Request>{request};

        // Call the invocable method
        Test.startTest();
        List<FlowReportToCampaignService.Result> results = FlowReportToCampaignService.addUniqueContactsToCampaign(requests);
        Test.stopTest();

        // Verify the results
        Assert.isFalse(results.isEmpty(), 'Results should not be empty');
        FlowReportToCampaignService.Result result = results[0];
        Assert.areEqual(1, result.campaignMembers.size(), 'There should be 1 unique campaign member excluding existing ones');
    }

    private static Id getReportId(String reportDeveloperName) {
        List<Report> reportList = [SELECT Id FROM Report WHERE DeveloperName = :reportDeveloperName LIMIT 1];
        if (reportList.isEmpty()) {
            return null;
        }
        return reportList[0].Id;
    }
}