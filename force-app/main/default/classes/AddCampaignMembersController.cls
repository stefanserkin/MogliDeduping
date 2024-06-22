public with sharing class AddCampaignMembersController {

    /**
     * Get all reports that the user has access to
     */
    @AuraEnabled(cacheable=true)
    public static List<Report> getReports() {
        try {
            return [
                SELECT Id, Name
                  FROM Report
                  WITH USER_MODE
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Get report columns
     */
    @AuraEnabled(cacheable=true)
    public static List<ReportColumn> getReportColumns(
        String reportId
    ) {
        try {
            List<ReportColumn> reportColumns = new List<ReportColumn>();
            // Run the report without detail rows
            Reports.ReportResults results = Reports.ReportManager.runReport(reportId);
            // Get the report extended metadata for detailed column information
            Reports.ReportExtendedMetadata reportMetadata = results.getReportExtendedMetadata();
            Map<String, Reports.DetailColumn> columnMap = reportMetadata.getDetailColumnInfo();
            for (Reports.DetailColumn detailColumn : columnMap.values()) {
                ReportColumn col = new ReportColumn();
                col.dataType = getDataTypeStringFromEnum(detailColumn.getDataType());
                col.name = detailColumn.getName();
                col.label = detailColumn.getLabel();
                reportColumns.add(col);
            }
            return reportColumns;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Convert data type to presentable string for UI
     */
    private static String getDataTypeStringFromEnum(
        Reports.ColumnDataType dataTypeEnum
    ) {
        String dataType = String.valueOf(dataTypeEnum);
        Integer breakIndex = dataType.indexOf('_');
        return dataType.left(breakIndex).toLowerCase().capitalize();
    }

    /**
     * Get a list of campaign members based on the contents of a specified report
     * Campaign members will be unique, based on the uniqueKeyColumn and matchingContactField
     */
    @AuraEnabled(cacheable=false)
    public static List<CampaignMember> getCampaignMembers(
        String requestString
    ) {
        try {
            CampaignMemberReportRequest request = (CampaignMemberReportRequest) JSON.deserialize(
                requestString,
                CampaignMemberReportRequest.class
            );
            CampaignMemberReportService service = new CampaignMemberReportService(request);
            return service.getCampaignMembers();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static String addCampaignMembers(
        List<CampaignMember> campaignMembers
    ) {
        try {
            Database.insert(campaignMembers, AccessLevel.USER_MODE);
            return 'success';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<FieldOption> getContactFields() {
        try {
            List<FieldOption> fieldOptions = new List<FieldOption>();
            Map <String, Schema.SObjectField> fieldMap = Contact.sObjectType.getDescribe().fields.getMap();
            for (String fieldName : fieldMap.keySet()) {
                DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
                String dataType = String.valueOf(dfr.getType()).toLowerCase().capitalize();
                fieldOptions.add(
                    new FieldOption(dfr.getLabel(), fieldName, dataType)
                );
            }
            return fieldOptions;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

}