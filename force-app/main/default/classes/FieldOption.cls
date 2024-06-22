public class FieldOption {
    
    @AuraEnabled
    public String label {get; set;}

    @AuraEnabled
    public String value {get; set;}

    @AuraEnabled
    public String dataType {get; set;}

    public FieldOption(String label, String value, String dataType) {
        this.label = label;
        this.value = value;
        this.dataType = dataType;
    }

}