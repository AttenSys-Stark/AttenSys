use core::num::traits::Zero;
use starknet::ContractAddress;

pub mod InputValidation {
    use super::*;

    // Constants for validation bounds
    pub const MAX_STRING_LENGTH: u32 = 1000;
    pub const MAX_PRICE_USD: u128 = 10000; // $10,000 max
    pub const MIN_PRICE_USD: u128 = 1; // $1 min
    pub const MAX_ARRAY_LENGTH: u32 = 1000;
    pub const MAX_EVENT_LOCATION: u8 = 1; // 0 = online, 1 = physical
    pub const MAX_REGISTRATION_STATUS: u8 = 1; // 0 = closed, 1 = open
    pub const MAX_FEE_PERCENTAGE: u128 = 20; // 20% max platform fee

    // Address validation
    pub fn validate_non_zero_address(address: ContractAddress) {
        assert(!address.is_zero(), 'Address cannot be zero');
    }

    pub fn validate_not_same_address(addr1: ContractAddress, addr2: ContractAddress) {
        assert(addr1 != addr2, 'Addresses cannot be same');
    }

    // String validation
    pub fn validate_string_not_empty(data: @ByteArray) {
        assert(data.len() > 0, 'String cannot be empty');
    }

    pub fn validate_string_length(data: @ByteArray, max_length: u32) {
        assert(data.len() <= max_length, 'String too long');
        assert(data.len() > 0, 'String cannot be empty');
    }

    // Amount validation - only check for zero since unsigned can't be negative
    pub fn validate_amount_not_zero_u256(amount: u256) {
        assert(amount != 0, 'Amount cannot be zero');
    }

    pub fn validate_amount_not_zero_u128(amount: u128) {
        assert(amount != 0, 'Amount cannot be zero');
    }

    pub fn validate_price_range(price: u128) {
        assert(price >= MIN_PRICE_USD, 'Price below minimum');
        assert(price <= MAX_PRICE_USD, 'Price above maximum');
    }

    pub fn validate_sufficient_balance_u256(balance: u256, amount: u256) {
        assert(balance >= amount, 'No withdrawable balance');
    }

    pub fn validate_sufficient_balance_u128(balance: u128, amount: u128) {
        assert(balance >= amount, 'No withdrawable balance');
    }

    // Event/Course specific validation
    pub fn validate_event_location(location: u8) {
        assert(location <= MAX_EVENT_LOCATION, 'Invalid event location');
    }

    pub fn validate_registration_status(status: u8) {
        assert(status <= MAX_REGISTRATION_STATUS, 'Invalid registration status');
    }

    pub fn validate_time_range(start_time: u256, end_time: u256) {
        assert(start_time != 0, 'Start time cannot be zero');
        assert(end_time > start_time, 'End time must be after start');
    }

    pub fn validate_identifier_exists(identifier: u128, max_identifier: u128) {
        assert(identifier != 0, 'Identifier cannot be zero');
        assert(identifier <= max_identifier, 'Identifier does not exist');
    }

    pub fn validate_identifier_exists_u256(identifier: u256, max_identifier: u256) {
        assert(identifier != 0, 'Identifier cannot be zero');
        assert(identifier <= max_identifier, 'Identifier does not exist');
    }

    // Status validation
    pub fn validate_not_suspended(is_suspended: bool) {
        assert(!is_suspended, 'Resource is suspended');
    }

    pub fn validate_not_canceled(is_canceled: bool) {
        assert(!is_canceled, 'Resource is canceled');
    }

    pub fn validate_registration_open(registration_status: u8) {
        assert(registration_status == 1, 'Registration is closed');
    }

    // Authorization validation
    pub fn validate_caller_authorization(expected: ContractAddress, actual: ContractAddress) {
        assert(expected == actual, 'unauthorized caller');
    }

    pub fn validate_admin_only(caller: ContractAddress, admin: ContractAddress) {
        validate_non_zero_address(caller);
        validate_non_zero_address(admin);
        assert(caller == admin, 'No withdrawable balance');
    }

    // Array and DOS protection
    pub fn validate_array_length<T>(array: @Array<T>) {
        assert(array.len() <= MAX_ARRAY_LENGTH, 'Array too large');
    }

    pub fn validate_fee_percentage(fee: u128) {
        assert(fee != 0, 'Fee cannot be zero');
        assert(fee <= 100, 'Fee cannot exceed 100%');
        assert(fee <= MAX_FEE_PERCENTAGE, 'Fee above platform maximum');
    }

    // Registration and interaction validation
    pub fn validate_not_already_registered(is_registered: bool) {
        assert(!is_registered, 'Already registered');
    }

    pub fn validate_already_registered(is_registered: bool) {
        assert(is_registered, 'Not registered');
    }

    pub fn validate_not_already_completed(is_completed: bool) {
        assert(!is_completed, 'Already completed');
    }

    pub fn validate_course_taken(is_taken: bool) {
        assert(is_taken, 'Course not taken');
    }

    // Withdrawal validation helpers
    pub fn validate_withdrawal_amount(amount: u128, available: u128) {
        validate_amount_not_zero_u128(amount);
        validate_sufficient_balance_u128(available, amount);
    }

    pub fn validate_sponsorship_deposit(
        sender: ContractAddress, event_organizer: ContractAddress, amount: u256, uri: @ByteArray,
    ) {
        validate_non_zero_address(sender);
        validate_non_zero_address(event_organizer);
        validate_amount_not_zero_u256(amount);
        validate_string_not_empty(uri);
        validate_not_same_address(sender, event_organizer);
    }

    // Combined validation functions for common operations
    pub fn validate_course_creation(
        owner: ContractAddress, course_name: @ByteArray, course_uri: @ByteArray, price: u128,
    ) {
        validate_non_zero_address(owner);
        validate_string_length(course_name, 100);
        validate_string_length(course_uri, 500);
        validate_price_range(price);
    }

    pub fn validate_event_creation(
        owner: ContractAddress,
        event_name: @ByteArray,
        event_uri: @ByteArray,
        start_time: u256,
        end_time: u256,
        location: u8,
        reg_status: u8,
    ) {
        validate_non_zero_address(owner);
        validate_string_length(event_name, 200);
        validate_string_length(event_uri, 500);
        validate_time_range(start_time, end_time);
        validate_event_location(location);
        validate_registration_status(reg_status);
    }
}
