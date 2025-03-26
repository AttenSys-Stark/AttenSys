// Module for admin and access control functions
pub mod admin_manager {
    use core::starknet::{
        ContractAddress, get_caller_address, contract_address_const,
    };
    use super::super::common::{AdminTransferred, AdminOwnershipClaimed};

    // Validate admin authorization
    pub fn validate_admin(
        admin_address: ContractAddress,
        caller_address: ContractAddress,
    ) {
        assert(caller_address == admin_address, 'unauthorized caller');
    }

    // Validate new admin address
    pub fn validate_new_admin(
        new_admin: ContractAddress,
    ) {
        assert(new_admin != zero_address(), 'zero address not allowed');
    }

    // Validate admin claim
    pub fn validate_admin_claim(
        intended_new_admin: ContractAddress,
        caller_address: ContractAddress,
    ) {
        assert(caller_address == intended_new_admin, 'unauthorized caller');
    }

    // Create admin transferred event data
    pub fn create_admin_transfer_data(
        old_admin: ContractAddress,
        new_admin: ContractAddress,
    ) -> AdminTransferred {
        AdminTransferred { 
            old_admin: old_admin, 
            new_admin: new_admin 
        }
    }

    // Create admin ownership claimed event data
    pub fn create_admin_claim_data(
        new_admin: ContractAddress,
    ) -> AdminOwnershipClaimed {
        AdminOwnershipClaimed { new_admin: new_admin }
    }

    // Get zero address
    fn zero_address() -> ContractAddress {
        contract_address_const::<0>()
    }
} 