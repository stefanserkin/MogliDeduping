public with sharing class ReportColumnOption {
    @AuraEnabled
    public String name {get; set;}

    @AuraEnabled
    public String label {get; set;}

    @AuraEnabled 
    public String dataType {get; set;}

    @AuraEnabled
    public Integer index {get; set;}

    @AuraEnabled
    public String labelAndDataType {get; set;}

    public ReportColumnOption(String name, String label, String dataType, Integer index) {
        this.name = name;
        this.label = label;
        this.dataType = dataType;
        this.index = index;
        this.labelAndDataType = label + ' (' + dataType + ')';
    }
}