use core::starknet::{ContractAddress, get_caller_address};
use crate::base::types::{Organization, Instructor};
use crate::events::{
    AdminOwnershipTransferred, AdminOwnershipClaimed,
};
use crate::utils::only_admin;
use crate::storage_groups::{
    AdminStorage, OrganizationStorage, InstructorStorage,
};

#[starknet::interface]
pub trait IAdminManagement<TContractState> {
    fn transfer_admin(ref self: TContractState, new_admin: ContractAddress);
    fn claim_admin_ownership(ref self: TContractState);
    fn get_admin(self: @TContractState) -> ContractAddress;
    fn get_new_admin(self: @TContractState) -> ContractAddress;
}

#[generate_trait]
pub impl AdminManagement of IAdminManagement<ContractState> {
    fn transfer_admin(ref self: ContractState, new_admin: ContractAddress) {
        assert(new_admin != self.zero_address(), 'zero address not allowed');
        assert(get_caller_address() == self.admin.read(), 'unauthorized caller');

        self.intended_new_admin.write(new_admin);
    }

    fn claim_admin_ownership(ref self: ContractState) {
        assert(get_caller_address() == self.intended_new_admin.read(), 'unauthorized caller');

        self.admin.write(self.intended_new_admin.read());
        self.intended_new_admin.write(self.zero_address());
    }

    fn get_admin(self: @ContractState) -> ContractAddress {
        self.admin.read()
    }

    fn get_new_admin(self: @ContractState) -> ContractAddress {
        self.intended_new_admin.read()
    }
}