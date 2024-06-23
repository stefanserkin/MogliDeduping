public with sharing class FlowReportColumnSelector {
    
    @InvocableMethod(
        label='Get Report Detail Columns'
        description='Returns column metadata for a the provided Report ID'
    )
    public static List<Result> getReportDetailColumns(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request request : requests) {
            Result result = new Result();
            result.reportColumnOptions = getReportColumnOptions(request.reportId);
            results.add(result);
        }
        return results;
    }

    /**
     * Get report detail column information from extended metadata
     */
    private static List<ReportColumnOption> getReportColumnOptions(String reportId) {
        List<ReportColumnOption> options = new List<ReportColumnOption>();
        // Run the report without detail rows
        Reports.ReportResults results = Reports.ReportManager.runReport(reportId);
        // Get the report extended metadata for detailed column information
        Reports.ReportExtendedMetadata reportMetadata = results.getReportExtendedMetadata();
        Map<String, Reports.DetailColumn> columnMap = reportMetadata.getDetailColumnInfo();
        Integer index = 0;
        for (Reports.DetailColumn detailColumn : columnMap.values()) {
            options.add(
                new ReportColumnOption(
                    detailColumn.getName(),
                    detailColumn.getLabel(),
                    getDataTypeStringFromEnum(detailColumn.getDataType()),
                    index
                )
            );
            index++;
        }
        return options;
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

    public class Request {
        @InvocableVariable(label='Report ID')
        public String reportId;
    }

    public class Result {
        @InvocableVariable(label='Report Columns')
        public List<ReportColumnOption> reportColumnOptions;
    }
}