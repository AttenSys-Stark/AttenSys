use attendsys::components::org::types::Bootcamp;
use core::starknet::ContractAddress;
#[starknet::interface]
pub trait IBootcampManagement<TContractState> {
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
    fn batch_certify_students(ref self: TContractState, org_: ContractAddress, bootcamp_id: u64);
    fn single_certify_student(
        ref self: TContractState,
        org_: ContractAddress,
        bootcamp_id: u64,
        students: ContractAddress,
    );
    fn suspend_org_bootcamp(
        ref self: TContractState, org_: ContractAddress, bootcamp_id_: u64, suspend: bool,
    );
    fn get_bootcamp_active_meet_link(
        self: @TContractState, org_: ContractAddress, bootcamp_id: u64,
    ) -> ByteArray;
    fn get_bootcamp_uploaded_video_link(
        self: @TContractState, org_: ContractAddress, bootcamp_id: u64,
    ) -> Array<ByteArray>;
    fn get_bootcamp_info(
        self: @TContractState, org_: ContractAddress, bootcamp_id: u64,
    ) -> Bootcamp;
    fn get_all_bootcamps_on_platform(self: @TContractState) -> Array<Bootcamp>;
    fn get_all_bootcamp_classes(
        self: @TContractState, org: ContractAddress, bootcamp_id: u64,
    ) -> Array<u64>;
    fn get_certified_student_bootcamp_address(
        self: @TContractState, org: ContractAddress, bootcamp_id: u64,
    ) -> Array<ContractAddress>;
    fn get_bootcamp_certification_status(
        self: @TContractState, org: ContractAddress, bootcamp_id: u64, student: ContractAddress,
    ) -> bool;
    fn is_bootcamp_suspended(
        self: @TContractState, org_: ContractAddress, bootcamp_id: u64,
    ) -> bool;
}
