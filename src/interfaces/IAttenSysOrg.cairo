mod admin_management;
mod bootcamp_management;
mod certificate_management;
mod class_attendance;
mod content_management;
mod organization_management;
mod sponsorship_management;
mod utils;


pub use admin_management::*;
pub use bootcamp_management::*;
pub use organization_management::*;
pub use sponsorship_management::*;
pub use content_management::*;
pub use class_attendance::*;
pub use certificate_management::*;

use core::starknet::{ContractAddress};
use core::array::Array; // Import Array type
use crate::base::types::{Student, Instructor, Bootcamp, Class, Organization, RegisteredBootcamp}; // Import missing types

#[starknet::interface]
pub trait IAttenSysOrg<TContractState> {
    fn create_org_profile(ref self: TContractState, org_name: ByteArray, org_ipfs_uri: ByteArray);
    fn add_instructor_to_org(
        ref self: TContractState, instructor: Array<ContractAddress>, org_name: ByteArray,
    );
    fn remove_instructor_from_org(ref self: TContractState, instructor: ContractAddress);
    fn create_bootcamp(
        ref self: TContractState,
        org_name: ByteArray,
        bootcamp_name: ByteArray,
        nft_name: ByteArray,
        nft_symbol: ByteArray,
        nft_uri: ByteArray,
        num_of_class_to_create: u256,
        bootcamp_ipfs_uri: ByteArray,
    );
    fn add_active_meet_link(
        ref self: TContractState,
        meet_link: ByteArray,
        bootcamp_id: u64,
        is_instructor: bool,
        org_address: ContractAddress,
    );
    fn add_uploaded_video_link(
        ref self: TContractState,
        video_link: ByteArray,
        is_instructor: bool,
        org_address: ContractAddress,
        bootcamp_id: u64,
    );
    fn register_for_bootcamp(
        ref self: TContractState, org_: ContractAddress, bootcamp_id: u64, student_uri: ByteArray,
    );
    fn approve_registration(
        ref self: TContractState, student_address: ContractAddress, bootcamp_id: u64,
    );
    fn decline_registration(
        ref self: TContractState, student_address: ContractAddress, bootcamp_id: u64,
    );
    fn mark_attendance_for_a_class(
        ref self: TContractState,
        org_: ContractAddress,
        instructor_: ContractAddress,
        class_id: u64,
        bootcamp_id: u64,
    );
    fn batch_certify_students(ref self: TContractState, org_: ContractAddress, bootcamp_id: u64);
    fn single_certify_student(
        ref self: TContractState, org_: ContractAddress, bootcamp_id: u64, students: ContractAddress
    );
    fn setSponsorShipAddress(ref self: TContractState, sponsor_contract_address: ContractAddress);
    fn sponsor_organization(
        ref self: TContractState, organization: ContractAddress, uri: ByteArray, amt: u256,
    );
    fn withdraw_sponsorship_fund(ref self: TContractState, amt: u256);
    fn suspend_organization(ref self: TContractState, org_: ContractAddress, suspend: bool);
    fn suspend_org_bootcamp(
        ref self: TContractState, org_: ContractAddress, bootcamp_id_: u64, suspend: bool,
    );
    fn get_bootcamp_active_meet_link(
        self: @TContractState, org_: ContractAddress, bootcamp_id: u64,
    ) -> ByteArray;
    fn get_bootcamp_uploaded_video_link(
        self: @TContractState, org_: ContractAddress, bootcamp_id: u64,
    ) -> Array<ByteArray>;
    fn get_all_registration_request(
        self: @TContractState, org_: ContractAddress,
    ) -> Array<Student>;
    fn get_org_instructors(
        self: @TContractState, org_: ContractAddress,
    ) -> Array<Instructor>;
    fn get_all_org_bootcamps(
        self: @TContractState, org_: ContractAddress,
    ) -> Array<Bootcamp>;
    fn get_all_bootcamps_on_platform(self: @TContractState) -> Array<Bootcamp>;
    fn get_all_org_classes(
        self: @TContractState, org_: ContractAddress,
    ) -> Array<Class>;
    fn get_instructor_org_classes(
        self: @TContractState, org_: ContractAddress, instructor: ContractAddress,
    ) -> Array<Class>;
    fn get_org_info(self: @TContractState, org_: ContractAddress) -> Organization;
    fn get_all_org_info(self: @TContractState) -> Array<Organization>;
    fn get_student_info(self: @TContractState, student_: ContractAddress) -> Student;
    fn get_student_classes(
        self: @TContractState, student: ContractAddress,
    ) -> Array<Class>;
    fn get_instructor_part_of_org(self: @TContractState, instructor: ContractAddress) -> bool;
    fn get_instructor_info(
        self: @TContractState, instructor: ContractAddress,
    ) -> Array<Instructor>;
    fn get_bootcamp_info(
        self: @TContractState, org_: ContractAddress, bootcamp_id: u64,
    ) -> Bootcamp;
    fn transfer_admin(ref self: TContractState, new_admin: ContractAddress);
    fn claim_admin_ownership(ref self: TContractState);
    fn get_admin(self: @TContractState) -> ContractAddress;
    fn get_new_admin(self: @TContractState) -> ContractAddress;
    fn get_org_sponsorship_balance(self: @TContractState, organization: ContractAddress) -> u256;
    fn is_bootcamp_suspended(
        self: @TContractState, org_: ContractAddress, bootcamp_id: u64,
    ) -> bool;
    fn is_org_suspended(self: @TContractState, org_: ContractAddress) -> bool;
    fn get_registered_bootcamp(
        self: @TContractState, student: ContractAddress
    ) -> Array<RegisteredBootcamp>;
    fn get_specific_organization_registered_bootcamp(
        self: @TContractState, org: ContractAddress, student: ContractAddress
    ) -> Array<RegisteredBootcamp>;
    fn get_class_attendance_status(
        self: @TContractState,
        org: ContractAddress,
        bootcamp_id: u64,
        class_id: u64,
        student: ContractAddress
    ) -> bool;
    fn get_all_bootcamp_classes(
        self: @TContractState, org: ContractAddress, bootcamp_id: u64
    ) -> Array<u64>;
    fn get_certified_student_bootcamp_address(
        self: @TContractState, org: ContractAddress, bootcamp_id: u64
    ) -> Array<ContractAddress>;
    fn get_bootcamp_certification_status(
        self: @TContractState, org: ContractAddress, bootcamp_id: u64, student: ContractAddress
    ) -> bool;
}