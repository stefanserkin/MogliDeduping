@IsTest
private class FlowReportColumnSelector_Test {

    private static final String REPORT_DEVELOPER_NAME = 'Mogli_Deduplication_Test_Report_yOe';
    private static final String CONTACT_ID_COLUMN_NAME = 'CONTACT_ID';
    private static final String PHONE_NUMBER_COLUMN_NAME = 'PHONE3';
    
    @IsTest(SeeAllData='true')
    static void testReportColumnOptions() {
        Id reportId = [SELECT Id FROM Report WHERE DeveloperName = :REPORT_DEVELOPER_NAME LIMIT 1].Id;
        FlowReportColumnSelector.Request request = new FlowReportColumnSelector.Request();
        request.reportId = reportId;
        List<FlowReportColumnSelector.Result> results = new List<FlowReportColumnSelector.Result>();
        Test.startTest();
        results = FlowReportColumnSelector.getReportDetailColumns(
            new List<FlowReportColumnSelector.Request>{ request }
        );
        Test.stopTest();
        Assert.isFalse(results[0].reportColumnOptions.isEmpty(), 'Should have received report column options');
        Assert.areEqual(CONTACT_ID_COLUMN_NAME, results[0].reportColumnOptions[0].name, 'Contact ID should be the first column');
        Assert.areEqual(PHONE_NUMBER_COLUMN_NAME, results[0].reportColumnOptions[1].name, 'Mobile Phone should be the second column');
    }

}