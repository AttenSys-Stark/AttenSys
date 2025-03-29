use core::starknet::{ContractAddress, get_caller_address};
use crate::base::types::{Student};
use crate::events::{StudentsCertified};
use crate::storage_groups::{StudentStorage, AttendanceStorage};

#[starknet::interface]
pub trait ICertificateManagement<TContractState> {
    fn batch_certify_students(ref self: TContractState, org_: ContractAddress, bootcamp_id: u64);
    fn single_certify_student(
        ref self: TContractState, org_: ContractAddress, bootcamp_id: u64, students: ContractAddress
    );
    fn get_bootcamp_certification_status(
        self: @TContractState, org: ContractAddress, bootcamp_id: u64, student: ContractAddress
    ) -> bool;
    fn get_certified_student_bootcamp_address(
        self: @TContractState, org: ContractAddress, bootcamp_id: u64
    ) -> Array<ContractAddress>;
}

#[generate_trait]
pub impl CertificateManagement of ICertificateManagement<ContractState> {
    fn batch_certify_students(
        ref self: ContractState, _org_: ContractAddress, _bootcamp_id: u64,
    ) {
        //only instructor under an organization issues certificate
        //all of the registered students with attendance
        let caller = get_caller_address();
        let is_instructor = self.instructor_part_of_org.entry((_org_, caller)).read();
        let mut attendance_counter = 0;
        assert(is_instructor, 'not an instructor');

        let mut arr_of_request = array![];
        for i in 0..self.org_to_requests.entry(_org_).len() {
            if self.org_to_requests.entry(_org_).at(i).status.read() == 1 {
                arr_of_request.append(
                    self.org_to_requests.entry(_org_).at(i).address_of_student.read()
                );
            }
        };
        
        let mut class_id_arr = array![];
        for i in 0..self.bootcamp_class_data_id.entry((_org_, _bootcamp_id)).len() {
            class_id_arr.append(
                self.bootcamp_class_data_id.entry((_org_, _bootcamp_id)).at(i).read()
            );
        };
        
        //@todo mint an nft associated to the bootcamp to each student.
        for i in 0..arr_of_request.len() {
            for k in 0..class_id_arr.len() {
                let reg_status = self
                    .student_attendance_status
                    .entry(
                        (
                            _org_,
                            _bootcamp_id,
                            *class_id_arr.at(k),
                            *arr_of_request.at(i)
                        )
                    )
                    .read();
                if reg_status {
                    attendance_counter += 1;
                }
            };
            
            let attendance_criteria = class_id_arr.len() * (1 / 2);
            if attendance_counter > attendance_criteria {
                self
                    .certify_student
                    .entry((_org_, _bootcamp_id, *arr_of_request.at(i)))
                    .write(true);
                self
                    .certified_students_for_bootcamp
                    .entry((_org_, _bootcamp_id))
                    .append()
                    .write(*arr_of_request.at(i));
                attendance_counter = 0;
            };
        };
        
        self.emit(
            StudentsCertified {
                org_address: _org_, 
                class_id: _bootcamp_id, 
                student_addresses: arr_of_request,
            },
        );
    }
    
    fn single_certify_student(
        ref self: ContractState,
        org_: ContractAddress,
        bootcamp_id: u64,
        students: ContractAddress
    ) {
        let caller = get_caller_address();
        let is_instructor = self.instructor_part_of_org.entry((org_, caller)).read();
        assert(is_instructor, 'not an instructor');
        //@todo check if student has been certified
        //@todo check if address is a registered student
        self.certify_student.entry((org_, bootcamp_id, students)).write(true);
        self
            .certified_students_for_bootcamp
            .entry((org_, bootcamp_id))
            .append()
            .write(students);
    }

}