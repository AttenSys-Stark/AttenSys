use core::starknet::ContractAddress;
use crate::interface::IAttenSysOrg::IAttenSysOrg;
use core::starknet::{ContractAddress, ClassHash, get_caller_address};



use crate::events::*;
use crate::storage_groups::*;
use crate::utils::*;


use crate::contracts::{
    OrganizationManagement, BootcampManagement, ContentManagement, 
    StudentManagement, CertificateManagement, InstructorManagement,
    SponsorshipManagement, AdminManagement
};

// types
use crate::base::types::{
    Organization, Bootcamp, Instructor, Class, Student, RegisteredBootcamp, Bootcampclass
};

//The contract
#[starknet::contract]
pub mod AttenSysOrg {
    

    use core::starknet::{
        ContractAddress, ClassHash, get_caller_address, syscalls::deploy_syscall, ClassHash,
        contract_address_const,
    };

    use core::starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
        MutableVecTrait,
    };
    

    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        class_hash: ClassHash,
        _token_address: ContractAddress,
        sponsorship_contract_address: ContractAddress,
    ) {
        core::starknet::storage::StoragePointerWriteAccess::write(self.hash, class_hash);
        core::starknet::storage::StoragePointerWriteAccess::write(self.token_address, _token_address);
        core::starknet::storage::StoragePointerWriteAccess::write( self.sponsorship_contract_address, sponsorship_contract_address,
        );
        core::starknet::storage::StoragePointerWriteAccess::write(self.admin, admin);
    }

    #[abi(embed_v0)]
    impl IAttenSysOrgImpl of IAttenSysOrg<ContractState> {

        fn create_org_profile(ref self: ContractState, org_name: ByteArray, org_ipfs_uri: ByteArray) {
            OrganizationManagement::create_org_profile(ref self, org_name, org_ipfs_uri)
        }
        
        fn add_instructor_to_org(ref self: ContractState, instructor: Array<ContractAddress>, org_name: ByteArray) {
            OrganizationManagement::add_instructor_to_org(ref self, instructor, org_name)
        }
        
        fn remove_instructor_from_org(ref self: ContractState, instructor: ContractAddress) {
            OrganizationManagement::remove_instructor_from_org(ref self, instructor)
        }
        
        // Content Management functions
        fn add_active_meet_link(
            ref self: ContractState,
            meet_link: ByteArray,
            bootcamp_id: u64,
            is_instructor: bool,
            org_address: ContractAddress,
        ) {
            ContentManagement::add_active_meet_link(ref self, meet_link, bootcamp_id, is_instructor, org_address)
        }
        
        fn add_uploaded_video_link(
            ref self: ContractState,
            video_link: ByteArray,
            is_instructor: bool,
            org_address: ContractAddress,
            bootcamp_id: u64,
        ) {
            ContentManagement::add_uploaded_video_link(ref self, video_link, is_instructor, org_address, bootcamp_id)
        }
        
        // Certificate Management functions
        fn batch_certify_students(ref self: ContractState, org_: ContractAddress, bootcamp_id: u64) {
            CertificateManagement::batch_certify_students(ref self, org_, bootcamp_id)
        }
        
        fn single_certify_student(
            ref self: ContractState, org_: ContractAddress, bootcamp_id: u64, students: ContractAddress
        ) {
            CertificateManagement::single_certify_student(ref self, org_, bootcamp_id, students)
        }
        
        // Sponsorship Management functions
        fn setSponsorShipAddress(ref self: ContractState, sponsor_contract_address: ContractAddress) {
            SponsorshipManagement::setSponsorShipAddress(ref self, sponsor_contract_address)
        }

        fn transfer_admin(ref self: ContractState, new_admin: ContractAddress) {
            AdminManagement::transfer_admin(ref self, new_admin)
        }

        fn claim_admin_ownership(ref self: ContractState) {
            AdminManagement::claim_admin_ownership(ref self)
        }


        fn get_admin(self: @ContractState) -> ContractAddress {
            AdminManagement::get_admin(self)
        }

        fn get_new_admin(self: @ContractState) -> ContractAddress {
            AdminManagement::get_new_admin(self)
        }

        fn create_bootcamp(
            // ref self: ContractState,
            org_name: ByteArray,
            bootcamp_name: ByteArray,
            nft_name: ByteArray,
            nft_symbol: ByteArray,
            nft_uri: ByteArray,
            num_of_class_to_create: u256,
            bootcamp_ipfs_uri: ByteArray,
        ) {
            BootCampManagement::create_bootcamp(
                org_name,
                bootcamp_name,
                nft_name,
                nft_symbol,
                nft_uri,
                num_of_class_to_create,
                bootcamp_ipfs_uri,
            )
        } 


        fn register_for_bootcamp(
        ref self: ContractState,
        org_: ContractAddress,
        bootcamp_id: u64,
        student_uri: ByteArray,
    ){
        BootCampManagement::register_for_bootcamp(ref self, org_, bootcamp_id, student_uri)
    }

        fn approve_registration(
            ref self: ContractState,
            student_address: ContractAddress,
            bootcamp_id: u64,
        ) {
            BootCampManagement::approve_registration(ref self, student_address, bootcamp_id)
        }

        fn decline_registration(
            ref self: ContractState,
            student_address: ContractAddress,
            bootcamp_id: u64,
        ) {
            BootCampManagement::decline_registration(ref self, student_address, bootcamp_id)
        }

        fn mark_attendance_for_a_class(
            ref self: ContractState,
            org_: ContractAddress,
            instructor_: ContractAddress,
            class_id: u64,
            bootcamp_id: u64,
        ) {
            BootCampManagement::mark_attendance_for_a_class(ref self, org_, instructor_, class_id, bootcamp_id)
    }   

    fn get_registered_bootcamp(
        self: @ContractState, student: ContractAddress
    ) -> Array<RegisteredBootcamp> {
        BootCampManagement::get_registered_bootcamp(self, student)
    }
    fn get_all_bootcamp_classes(
        self: @ContractState, org: ContractAddress, bootcamp_id: u64
    ){
        BootCampManagement::get_all_bootcamp_classes(self, org, bootcamp_id)
    }

    fn get_certified_student_bootcamp_address(
        self: @ContractState, org: ContractAddress, bootcamp_id: u64
    ){
        BootCampManagement::get_certified_student_bootcamp_address(self, org, bootcamp_id)
    }


    fn get_bootcamp_certification_status(
        self: @ContractState, org: ContractAddress, bootcamp_id: u64, student: ContractAddress
    ){
        BootCampManagement::get_bootcamp_certification_status(self, org, bootcamp_id, student)  
    }

    fn batch_certify_students(ref self: TContractState, org_: ContractAddress, bootcamp_id: u64){
        CertificateManagement::batch_certify_students(ref self, org_, bootcamp_id)
    }
    fn single_certify_student(
        ref self: TContractState, org_: ContractAddress, bootcamp_id: u64, students: ContractAddress
    ){
        CertificateManagement::single_certify_student(ref self, org_, bootcamp_id, students)
    }
    fn get_bootcamp_certification_status(
        self: @TContractState, org: ContractAddress, bootcamp_id: u64, student: ContractAddress
    ) {
        CertificateManagement::get_bootcamp_certification_status(self, org, bootcamp_id, student)
    };
    fn get_certified_student_bootcamp_address(
        self: @TContractState, org: ContractAddress, bootcamp_id: u64
    ){
        CertificateManagement::get_certified_student_bootcamp_address(self, org, bootcamp_id)
    }



    fn get_class_attendance_status(
        self: @TContractState,
        org: ContractAddress,
        bootcamp_id: u64,
        class_id: u64,
        student: ContractAddress
    ){
        ClassAttendance::get_class_attendance_status(self, org, bootcamp_id, class_id, student)
    };
    
    fn create_a_class(
        ref self: TContractState,
        org_: ContractAddress,
        num_of_class_to_create: u256,
        bootcamp_id: u64,
    ){
        ClassAttendance::create_a_class(ref self, org_, num_of_class_to_create, bootcamp_id)
    }




    fn add_active_meet_link(
        ref self: TContractState,
        meet_link: ByteArray,
        bootcamp_id: u64,
        is_instructor: bool,
        org_address: ContractAddress,
    ){
        ContentManagement::add_active_meet_link(ref self, meet_link, bootcamp_id, is_instructor, org_address)
    }
    fn add_uploaded_video_link(
        ref self: TContractState,
        video_link: ByteArray,
        is_instructor: bool,
        org_address: ContractAddress,
        bootcamp_id: u64,
    ){
        ContentManagement::add_uploaded_video_link(ref self, video_link, is_instructor, org_address, bootcamp_id)
    }
    fn get_bootcamp_active_meet_link(
        self: @TContractState, org_: ContractAddress, bootcamp_id: u64,
    ){
        ContentManagement::get_bootcamp_active_meet_link(self, org_, bootcamp_id)
    };
    fn get_bootcamp_uploaded_video_link(
        self: @TContractState, org_: ContractAddress, bootcamp_id: u64,
    ){
        ContentManagement::get_bootcamp_uploaded_video_link(self, org_, bootcamp_id)
    };


    fn create_org_profile(ref self: TContractState, org_name: ByteArray, org_ipfs_uri: ByteArray){
        OrganizationManagement::create_org_profile(ref self, org_name, org_ipfs_uri)
    }
    fn add_instructor_to_org(ref self: TContractState, instructor: Array<ContractAddress>, org_name: ByteArray){
        OrganizationManagement::add_instructor_to_org(ref self, instructor, org_name)
    }
    fn remove_instructor_from_org(ref self: TContractState, instructor: ContractAddress){
        OrganizationManagement::remove_instructor_from_org(ref self, instructor)
    }
    fn suspend_organization(ref self: TContractState, org_: ContractAddress, suspend: bool){
        OrganizationManagement::suspend_organization(ref self, org_, suspend)
    }
    fn get_org_info(self: @TContractState, org_: ContractAddress){
        OrganizationManagement::get_org_info(self, org_)
    }
    fn get_all_org_info(self: @TContractState){
        OrganizationManagement::get_all_org_info(self)
    }
    fn get_org_instructors(self: @TContractState, org_: ContractAddress)[{
        OrganizationManagement::get_org_instructors(self, org_)
    }]
    fn is_org_suspended(self: @TContractState, org_: ContractAddress){
        OrganizationManagement::is_bootcamp_suspended(self, org_)
    }


    fn setSponsorShipAddress(ref self: TContractState, sponsor_contract_address: ContractAddress){
        SponsorshipManagement::setSponsorShipAddress(self, sponsor_contract_address)
    }
    fn sponsor_organization(
        ref self: TContractState, organization: ContractAddress, uri: ByteArray, amt: u256,
    ){
        SponsorshipManagement::sponsor_contract_address(self, orgnization, uri, amt)
    }
    fn withdraw_sponsorship_fund(ref self: TContractState, amt: u256){
        SponsorshipManagement::withdraw_sponsorship_fund(self, amt)
    }
    fn get_org_sponsorship_balance(self: @TContractState, organization: ContractAddress){
        SponsorshipManagement::get_org_sponsorship_balance(self, organization)
    }

    #[generate_trait]
                impl InternalFunctions of InternalFunctionsTrait {
                    fn zero_address(self: @ContractState) -> ContractAddress {
                        contract_address_const::<0>()
                    }
                }

}
