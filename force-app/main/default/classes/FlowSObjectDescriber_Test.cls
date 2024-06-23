@IsTest
private class FlowSObjectDescriber_Test {
    
    @IsTest
    static void testGetSObjectFields() {
        FlowSObjectDescriber.Request request = new FlowSObjectDescriber.Request();
        request.sObjectApiName = 'Contact';

        List<FlowSObjectDescriber.Result> results;
        Test.startTest();
        results = FlowSObjectDescriber.getSObjectFields(
            new List<FlowSObjectDescriber.Request>{ request }
        );
        Test.stopTest();

        Assert.isFalse(results[0].fields.isEmpty(), 'Should have received sobject fields');
        
        Set<String> fieldApiNames = new Set<String>();
        for (SObjectFieldOption option : results[0].fields) {
            fieldApiNames.add(option.name.toLowerCase());
        }
        Assert.isTrue(fieldApiNames.contains('phone'), 'Should have received Phone as a contact field');
        Assert.isTrue(fieldApiNames.contains('mobilephone'), 'Should have received Mobile Phone as a contact field');
    }

}