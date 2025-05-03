use attendsys::components::org::types::{Class, RegisteredBootcamp, Student};
use core::starknet::ContractAddress;
#[starknet::interface]
pub trait IStudentManagement<TContractState> {
    fn get_student_info(self: @TContractState, student_: ContractAddress) -> Student;
    fn get_student_classes(self: @TContractState, student: ContractAddress) -> Array<Class>;
    fn get_registered_bootcamp(
        self: @TContractState, student: ContractAddress,
    ) -> Array<RegisteredBootcamp>;
    fn get_specific_organization_registered_bootcamp(
        self: @TContractState, org: ContractAddress, student: ContractAddress,
    ) -> Array<RegisteredBootcamp>;
}
