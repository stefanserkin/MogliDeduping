import { LightningElement, api, track } from 'lwc';

export default class Combobox extends LightningElement {
    @api classes;
    @api label;
    @api placeholder;
    @api value;
    @api options;
    @api disabled = false;
    
    @track isFocused = false;
    @track isOpen = false;
    @track hasInteracted = false;

    filteredOptions = [];
    domElement;

    constructor() {
        super();
        this.handleOutsideClick = this.handleOutsideClick.bind(this);
    }

    connectedCallback() {
        this.filteredOptions = [...this.options];
        document.addEventListener('click', this.handleOutsideClick);
    }

    disconnectedCallback() {
        document.removeEventListener('click', this.handleOutsideClick);
    }

    filterOptions(event) {
        const filterText = event.detail.value;
        this.filteredOptions = this.options.filter(option => {
            return option.label.toLowerCase().includes(filterText.toLowerCase());
        });
    }

    handleSelectOption(event) {
        this.value = event.currentTarget.dataset.label;
        const custEvent = new CustomEvent(
            'selectoption', {
                detail: {
                    value: event.currentTarget.dataset.value,
                    label: event.currentTarget.dataset.label
                }
            }
        );
        this.dispatchEvent(custEvent);

        // Close the picklist options
        this.isFocused = false;
        this.isOpen = false;
        this.hasInteracted = true;
        this.updateValidity();
    }

    get dropdownClasses() {
        let dropdownClasses = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
        // Show dropdown list on focus
        if (this.isOpen) {
            dropdownClasses += ' slds-is-open';
        }
        return dropdownClasses;
    }

    handleOutsideClick(event) {
        if ((!this.isFocused) && (this.isOpen)) { 
            // Fetch the dropdown DOM node
            let domElement = this.template.querySelector('div[data-id="resultBox"]');
            // Is the clicked element within the dropdown 
            if (domElement && !domElement.contains(event.target)) {
                this.isOpen = false;
            }
        }
        this.updateValidity();
    }

    handleFocus() {
        this.isFocused = true;
        this.isOpen = true;
    }

    handleBlur() {
        this.isFocused = false;
        this.hasInteracted = true;
    }

    updateValidity() {
        // Ensure the user has interacted with the field before validating
        if (this.hasInteracted) {
            this.template.querySelector('lightning-input').reportValidity();
        }
    }

}