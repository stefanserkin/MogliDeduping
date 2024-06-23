public class SObjectFieldOption {
    @AuraEnabled
    public String name {get; set;}

    @AuraEnabled
    public String label {get; set;}

    @AuraEnabled
    public String dataType {get; set;}

    @AuraEnabled
    public String sObjectName {get; set;}

    @AuraEnabled
    public String labelAndName {get; set;}

    public SObjectFieldOption(String name, String label, String dataType, String sObjectName) {
        this.name = name;
        this.label = label;
        this.dataType = dataType;
        this.sObjectName = sObjectName;
        this.labelAndName = label + ' (' + name + ')';
    }
}