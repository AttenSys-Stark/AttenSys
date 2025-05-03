use core::starknet::ClassHash;
#[starknet::interface]
pub trait IAttenSysOrg<TContractState> {
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}
