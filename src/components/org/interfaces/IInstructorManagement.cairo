use attendsys::components::org::types::Instructor;
use core::starknet::ContractAddress;
#[starknet::interface]
pub trait IInstructorManagement<TContractState> {
    fn get_instructor_part_of_org(self: @TContractState, instructor: ContractAddress) -> bool;
    fn get_instructor_info(self: @TContractState, instructor: ContractAddress) -> Array<Instructor>;
}
