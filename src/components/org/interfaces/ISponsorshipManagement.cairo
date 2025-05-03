use core::starknet::ContractAddress;
#[starknet::interface]
pub trait ISponsorshipManagement<TContractState> {
    fn setSponsorShipAddress(ref self: TContractState, sponsor_contract_address: ContractAddress);
    fn sponsor_organization(
        ref self: TContractState, organization: ContractAddress, uri: ByteArray, amt: u256,
    );
    fn withdraw_sponsorship_fund(ref self: TContractState, amt: u256);
}
