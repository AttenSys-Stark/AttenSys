use core::starknet::{ContractAddress, get_caller_address};
use crate::events::{SponsorshipAddressSet, OrganizationSponsored, SponsorshipFundWithdrawn};
use crate::storage_groups::{SponsorshipStorage, AdminStorage};
use crate::utils::only_admin;

#[starknet::interface]
pub trait ISponsorshipManagement<TContractState> {
    fn setSponsorShipAddress(ref self: TContractState, sponsor_contract_address: ContractAddress);
    fn sponsor_organization(
        ref self: TContractState, organization: ContractAddress, uri: ByteArray, amt: u256,
    );
    fn withdraw_sponsorship_fund(ref self: TContractState, amt: u256);
    fn get_org_sponsorship_balance(self: @TContractState, organization: ContractAddress) -> u256;
}

#[generate_trait]
pub impl SponsorshipManagement of ISponsorshipManagement<ContractState> {
    fn setSponsorShipAddress(
        ref self: ContractState, sponsor_contract_address: ContractAddress,
    ) {
        only_admin(ref self);
        assert(!sponsor_contract_address.is_zero(), 'Null address not allowed');
        self.sponsorship_contract_address.write(sponsor_contract_address);
        self.emit(SponsorshipAddressSet { sponsor_contract_address });
    }


    fn sponsor_organization(
        ref self: ContractState, organization: ContractAddress, uri: ByteArray, amt: u256,
    ) {
        assert(!organization.is_zero(), 'not an instructor');
        assert(uri.len() > 0, 'uri is empty');

        let sender = get_caller_address();
        let status: bool = self.created_status.entry(organization).read();
        if (status) {
            //assert organization not suspended
            assert(!self.org_suspended.entry(organization).read(), 'organization suspended');
            let balanceBefore = self.org_to_balance_of_sponsorship.entry(organization).read();
            self.org_to_balance_of_sponsorship.entry(organization).write(balanceBefore + amt);
            let sponsor_contract_address = self.sponsorship_contract_address.read();
            let token_contract_address = self.token_address.read();
            let sponsor_dispatcher = IAttenSysSponsorDispatcher {
                contract_address: sponsor_contract_address,
            };
            sponsor_dispatcher.deposit(sender, token_contract_address, amt);
            self.emit(Sponsor { amt, uri, organization });
        } else {
            panic!("not an organization");
        }
    }

    fn withdraw_sponsorship_fund(ref self: ContractState, amt: u256) {
        let organization = get_caller_address();
        assert(amt > 0, 'Invalid withdrawal amount');
        let status: bool = self.created_status.entry(organization).read();
        if (status) {
            assert(
                self.org_to_balance_of_sponsorship.entry(organization).read() >= amt,
                'insufficient funds',
            );
            let contract_address = self.token_address.read();
            let sponsor_contract_address = self.sponsorship_contract_address.read();
            let sponsor_dispatcher = IAttenSysSponsorDispatcher {
                contract_address: sponsor_contract_address,
            };
            sponsor_dispatcher.withdraw(contract_address, amt);

            let balanceBefore = self.org_to_balance_of_sponsorship.entry(organization).read();
            self.org_to_balance_of_sponsorship.entry(organization).write(balanceBefore - amt);
            self.emit(Withdrawn { amt, organization });
        } else {
            panic!("not an organization");
        }
    }


    fn get_org_sponsorship_balance(
        self: @ContractState, organization: ContractAddress,
    ) -> u256 {
        self.org_to_balance_of_sponsorship.entry(organization).read()
    }
    

}