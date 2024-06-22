public class ReportColumn {
    
    @AuraEnabled
    public String name {get; set;}

    @AuraEnabled
    public String label {get; set;}

    @AuraEnabled 
    public String dataType {get; set;}

    @AuraEnabled
    public Integer index {get; set;}

}