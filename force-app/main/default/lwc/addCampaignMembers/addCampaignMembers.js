import { LightningElement, api, wire, track } from 'lwc';
import { RefreshEvent } from 'lightning/refresh';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getReports from '@salesforce/apex/AddCampaignMembersController.getReports';
import getReportColumns from '@salesforce/apex/AddCampaignMembersController.getReportColumns';
import getContactFields from '@salesforce/apex/AddCampaignMembersController.getContactFields';
import getCampaignMembers from '@salesforce/apex/AddCampaignMembersController.getCampaignMembers';
import addCampaignMembers from '@salesforce/apex/AddCampaignMembersController.addCampaignMembers';

export default class AddCampaignMembers extends LightningElement {
    @api recordId;
    isLoading = false;
    isConfirmMode = false;
    error;
    
    campaignMembers;

    wiredReports = [];
    reports;
    wiredReportColumns = [];
    reportColumns;

    @track reportOptions = [];

    reportId;
    reportName;
    contactIdColumn;
    uniqueKeyColumn;
    mappedContactField;
    uniqueKeyDataType;
    contactFields;

    /**
     * Data
     */
    @wire(getContactFields)
    wiredFields(result) {
        if (result.data) {
            this.contactFields = result.data;
        } else if (result.error) {
            console.error(result.error);
        }
    }

    @wire(getReports)
    wiredReportResult(result) {
        this.isLoading = true;
        this.wiredReports = result;
        if (result.data) {
            const rows = JSON.parse(JSON.stringify(result.data));
            this.reportOptions = rows.map(row => ({
                label: row.Name,
                value: row.Id
            }));
            this.reports = rows;
            this.error = undefined;
            this.isLoading = false;
        } else if (result.error) {
            this.reports = undefined;
            this.error = result.error;
            console.error(this.error);
            this.isLoading = false;
        }
    }

    @wire(getReportColumns, {reportId: '$reportId'})
    wiredReportColumnResult(result) {
        this.wiredReportColumns = result;
        this.isLoading = true;
        if (result.data) {
            this.reportColumns = JSON.parse( JSON.stringify(result.data) );;
            this.error = undefined;
            this.isLoading = false;

        } else if (result.error) {
            this.reportColumns = undefined;
            this.error = error;
            this.isLoading = false;
        }
    }

    /**
     * Combobox options
     */
    dataTypeOptions = [
        { label: 'Phone', value: 'Phone' },
        { label: 'Email', value: 'Email' }
    ];

    get contactFieldOptions() {
        if (!this.contactFields || !this.uniqueKeyDataType) return;
        return this.sortObjectsByLabel(
            this.contactFields.filter(obj => {
                return obj.dataType === 'String' || obj.dataType === this.uniqueKeyDataType;
            })
        );
    }

    get uniqueKeyColumnOptions() {
        if (!this.reportColumns || !this.uniqueKeyDataType) return;
        const objs = this.reportColumns.filter(obj => {
            return obj.dataType === 'String' || obj.dataType === this.uniqueKeyDataType;
        });
        return this.sortObjectsByLabel(
            objs.map(obj => ({
                label: obj.label,
                value: obj.name
            }))
        );
    }

    get contactIdColumnOptions() {
        if (!this.reportColumns) return;
        const objs = this.reportColumns.filter(obj => {
            return obj.dataType === 'String' || obj.dataType === 'Id';
        });
        return this.sortObjectsByLabel(
            objs.map(obj => ({
                label: obj.label,
                value: obj.name
            }))
        );
    }

    /**
     * Event handlers
     */
    handleReportSelection(event) {
        this.reportId = event.detail.value;
        this.reportName = event.detail.label;
    }

    handleContactIdColumnSelection(event) {
        this.contactIdColumn = event.detail.value;
    }

    handleUniqueKeyColumnSelection(event) {
        this.uniqueKeyColumn = event.detail.value;
    }

    handleMappedContactFieldSelection(event) {
        this.mappedContactField = event.detail.value;
    }
    
    handleDataTypeSelection(event) {
        this.uniqueKeyDataType = event.detail.value;
    }

    handleSubmit() {
        this.isLoading = true;
        const requestString = JSON.stringify(this.requestObj);

        getCampaignMembers({requestString: requestString})
            .then(result => {
                this.campaignMembers = result;
                this.isConfirmMode = true;
                this.isLoading = false;
            }).catch(error => {
                this.error = error;
                console.error(this.error);
                this.isLoading = false;
            });
    }

    handleAddCampaignMembers() {
        this.isLoading = true;
        addCampaignMembers({campaignMembers: this.campaignMembers})
            .then(result => {
                if (result === 'success') {
                    const toastEvent = new ShowToastEvent({
                        title: 'Success',
                        message: 'All campaign members were added to the campaign',
                        variant: 'success'
                    });
                    this.dispatchEvent(toastEvent);
                    this.dispatchEvent(new RefreshEvent());
                    this.isConfirmMode = false;
                    this.isLoading = false;
                }
            }).catch(error => {
                this.error = error;
                console.error(this.error);
                this.isLoading = false;
            });
    }

    get requestObj() {
        return {
            campaignId: this.recordId,
            reportId: this.reportId,
            contactIdColumn: this.contactIdColumn,
            uniqueKeyColumn: this.uniqueKeyColumn,
            mappedContactField: this.mappedContactField,
            uniqueKeyDataType: this.uniqueKeyDataType
        };
    }

    /**
     * Labels and messaging
     */
    get uniqueKeyComboboxLabel() {
        return `Which report column has the ${this.uniqueKeyDataType.toLowerCase()} value?`;
    }

    get mappedContactFieldComboboxLabel() {
        return `Which field on the contact holds the ${this.uniqueKeyDataType.toLowerCase()} value?`;
    }

    get confirmationMessage() {
        if (this.campaignMembersNotFound) {
            return `No unique contacts were found, based on ${this.uniqueKeyDataType}`;
        } else if (this.campaignMembers.length == 1) {
            return `Found ${this.campaignMembers.length} unique contact, based on ${this.uniqueKeyDataType}. Are you sure you would like to add this contact to the campaign?`;
        } else if (this.campaignMembers.length > 1) {
            return `Found ${this.campaignMembers.length} unique contacts, based on ${this.uniqueKeyDataType}. Are you sure you would like to add these contacts to the campaign?`;
        }
    }

    /**
     * Settings and controls
     */
    get submitIsDisabled() {
        return !(this.reportId &&
            this.contactIdColumn &&
            this.uniqueKeyColumn &&
            this.mappedContactField &&
            this.uniqueKeyDataType);
    }

    get campaignMembersNotFound() {
        return !this.campaignMembers || this.campaignMembers.length == 0;
    }

    handleExitConfirmMode() {
        this.isConfirmMode = false;
    }

    /**
     * Utils
     */
    sortObjectsByLabel(lstObjects) {
        lstObjects.sort((a, b) => {
            const labelA = a.label.toUpperCase();
            const labelB = b.label.toUpperCase();
            return labelA.localeCompare(labelB);
        });
        return lstObjects;
    }

}