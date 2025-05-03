use core::starknet::ContractAddress;
#[starknet::interface]
pub trait IClassManagement<TContractState> {
    fn mark_attendance_for_a_class(
        ref self: TContractState,
        org_: ContractAddress,
        instructor_: ContractAddress,
        class_id: u64,
        bootcamp_id: u64,
    );
    fn get_class_attendance_status(
        self: @TContractState,
        org: ContractAddress,
        bootcamp_id: u64,
        class_id: u64,
        student: ContractAddress,
    ) -> bool;
}
