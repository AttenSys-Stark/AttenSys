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
pub trait IClassAttendance<TContractState> {
    fn get_class_attendance_status(
        self: @TContractState,
        org: ContractAddress,
        bootcamp_id: u64,
        class_id: u64,
        student: ContractAddress
    ) -> bool;
    
    fn create_a_class(
        ref self: TContractState,
        org_: ContractAddress,
        num_of_class_to_create: u256,
        bootcamp_id: u64,
    );
    
}

#[generate_trait]
pub impl ClassAttendance of IClassAttendance<ContractState> {
    fn get_class_attendance_status(
        self: @ContractState,
        org: ContractAddress,
        bootcamp_id: u64,
        class_id: u64,
        student: ContractAddress
    ) -> bool {
        let mut instructor_class = self
            .org_instructor_classes
            .entry((org, org))
            .at(class_id)
            .read();
        assert(instructor_class.active_status, 'not a class');
        let class_id_len = self.bootcamp_class_data_id.entry((org, bootcamp_id)).len();
        assert(class_id < class_id_len && class_id >= 0, 'invalid class id');

        let reg_status = self
            .student_attendance_status
            .entry((org, bootcamp_id, class_id, student))
            .read();
        reg_status}
    

    
    
    fn create_a_class(
        ref self: ContractState,
        org_: ContractAddress,
        num_of_class_to_create: u256,
        bootcamp_id: u64,
    ) {
        let caller = get_caller_address();
        let status: bool = self.instructor_part_of_org.entry((org_, caller)).read();
        // check if an instructor is associated to an organization
        if status {
            let class_data: Class = Class {
                address_of_org: org_,
                instructor: caller,
                num_of_reg_students: 0,
                active_status: true,
                bootcamp_id: bootcamp_id,
            };
            // update the org_instructor to classes created
            self.org_instructor_classes.entry((org_, caller)).append().write(class_data);
            // update all general classes linked to org
            let mut org: Organization = self.organization_info.entry(org_).read();
            org.number_of_all_classes += num_of_class_to_create;
            self.organization_info.entry(org_).write(org);

            for i in 0
                ..num_of_class_to_create {
                    self
                        .bootcamp_class_data_id
                        .entry((org_, bootcamp_id))
                        .append()
                        .write(i.try_into().unwrap())
                }
        } else {
            panic!("not an instructor in this org");
        }
    }
    
}