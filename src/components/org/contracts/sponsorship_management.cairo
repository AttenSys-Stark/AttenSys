use attendsys::components::org::interfaces::ISponsorshipManagement::ISponsorshipManagement;
#[starknet::component]
pub mod SponsorshipManagementComponent {
    use super::AttenSysOrg;
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    pub struct Storage {
        // sponsorship_contract_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Sponsor: Sponsor,
        Withdrawn: Withdrawn,
        SponsorshipAddressSet: SponsorshipAddressSet,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Sponsor {
        pub amt: u256,
        pub uri: ByteArray,
        #[key]
        pub organization: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Withdrawn {
        pub amt: u256,
        #[key]
        pub organization: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SponsorshipAddressSet {
        pub sponsor_contract_address: ContractAddress,
    }


    #[embeddable_as(SponsorshipManagementImpl)]
    impl SponsorshipManagementComponentImpl<
        TContractState, +HasComponent<TContractState>,
    > of super::ISponsorshipManagement<ComponentState<TContractState>> {
        fn setSponsorShipAddress(
            ref self: ComponentState<TContractState>, sponsor_contract_address: ContractAddress,
        ) {
            self.only_admin();
            assert(!sponsor_contract_address.is_zero(), 'Null address not allowed');
            self.sponsorship_contract_address.write(sponsor_contract_address);
            self.emit(SponsorshipAddressSet { sponsor_contract_address });
        }

        fn sponsor_organization(
            ref self: ComponentState<TContractState>,
            organization: ContractAddress,
            uri: ByteArray,
            amt: u256,
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

        fn withdraw_sponsorship_fund(ref self: ComponentState<TContractState>, amt: u256) {
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
                // let contract_address = self.token_address.read();
                // let sponsor_dispatcher = IAttenSysSponsorDispatcher { contract_address };
                /// @maintainer What's the need for this deposit func, I'm guessing it's an error
                // sponsor_dispatcher.deposit(organization, self.token_address.read(), amt);
                self.emit(Withdrawn { amt, organization });
            } else {
                panic!("not an organization");
            }
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn only_admin(ref self: ComponentState<TContractState>) {
            let _caller = get_caller_address();
            assert(_caller == self.admin.read(), 'Not admin');
        }
    }
}
