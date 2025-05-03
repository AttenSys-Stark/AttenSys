use attendsys::components::org::interfaces::IAdminManagement::IAdminManagement;
use super::super::super::super::contracts::attensys_org::AttenSysOrg;
#[starknet::component]
pub mod AdminManagementComponent {
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, contract_address_const, get_caller_address};

    #[storage]
    struct Storage {
        // admin: ContractAddress,
        // intended_new_admin: ContractAddress,
        parent: AttenSysOrg,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(AdminManagementImpl)]
    impl AdminManagementComponentImpl<
        TContractState, +HasComponent<TContractState>,
    > of super::IAdminManagement<ComponentState<TContractState>> {
        fn transfer_admin(ref self: ComponentState<TContractState>, new_admin: ContractAddress) {
            assert(new_admin != self.zero_address(), 'zero address not allowed');
            assert(get_caller_address() == self.admin.read(), 'unauthorized caller');

            self.intended_new_admin.write(new_admin);
        }

        fn claim_admin_ownership(ref self: ComponentState<TContractState>) {
            assert(get_caller_address() == self.intended_new_admin.read(), 'unauthorized caller');

            self.admin.write(self.intended_new_admin.read());
            self.intended_new_admin.write(self.zero_address());
        }

        fn get_admin(self: @ComponentState<TContractState>) -> ContractAddress {
            self.admin.read()
        }

        fn get_new_admin(self: @ComponentState<TContractState>) -> ContractAddress {
            self.intended_new_admin.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn zero_address(self: @ComponentState<TContractState>) -> ContractAddress {
            contract_address_const::<0>()
        }
    }
}
