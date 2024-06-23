public with sharing class FlowSObjectDescriber {

    @InvocableMethod(
        label='Get SObject Fields' 
        description='Get a collection of fields for a particular SObject type'
    )
    public static List<Result> getSObjectFields(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request request : requests){
            Result result = new Result();
            result.fields = getSObjectFieldOptions(request.sObjectApiName);
            results.add(result);
        }
        return results;
    }

    private static List<SObjectFieldOption> getSObjectFieldOptions(String sObjectApiName) {
        List<SObjectFieldOption> fieldOptions = new List<SObjectFieldOption>();
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(sObjectApiName).getDescribe().fields.getMap();
        for (String fieldName : fieldMap.keySet()) {
            DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
            if (fieldDescribe.isAccessible()) {
                fieldOptions.add( 
                    new SObjectFieldOption( 
                        fieldName, 
                        fieldDescribe.getLabel(), 
                        String.valueOf(fieldDescribe.getType()), 
                        sObjectApiName
                    ) 
                );
            }
        }
        return fieldOptions;
    }

    public class Request {
        @InvocableVariable(label='SObject API Name' required=true)
        public string sObjectApiName;
    }

    public class Result {
        @InvocableVariable(label='SObject Fields')
        public List<SObjectFieldOption> fields;
    }
}