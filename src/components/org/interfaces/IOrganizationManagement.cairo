use attendsys::components::org::types::{Bootcamp, Class, Instructor, Organization, Student};
use core::starknet::ContractAddress;
#[starknet::interface]
pub trait IOrganizationManagement<TContractState> {
    fn create_org_profile(ref self: TContractState, org_name: ByteArray, org_ipfs_uri: ByteArray);
    fn add_instructor_to_org(
        ref self: TContractState, instructor: Array<ContractAddress>, org_name: ByteArray,
    );
    fn remove_instructor_from_org(ref self: TContractState, instructor: ContractAddress);
    fn suspend_organization(ref self: TContractState, org_: ContractAddress, suspend: bool);
    fn get_all_registration_request(self: @TContractState, org_: ContractAddress) -> Array<Student>;
    fn get_org_instructors(self: @TContractState, org_: ContractAddress) -> Array<Instructor>;
    fn get_all_org_bootcamps(self: @TContractState, org_: ContractAddress) -> Array<Bootcamp>;
    fn get_all_org_classes(self: @TContractState, org_: ContractAddress) -> Array<Class>;
    fn get_instructor_org_classes(
        self: @TContractState, org_: ContractAddress, instructor: ContractAddress,
    ) -> Array<Class>;
    fn get_org_info(self: @TContractState, org_: ContractAddress) -> Organization;
    fn get_all_org_info(self: @TContractState) -> Array<Organization>;
    fn get_org_sponsorship_balance(self: @TContractState, organization: ContractAddress) -> u256;

    fn is_org_suspended(self: @TContractState, org_: ContractAddress) -> bool;
}
