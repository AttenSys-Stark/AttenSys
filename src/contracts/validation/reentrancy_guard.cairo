use starknet::ContractAddress;

pub mod ReentrancyGuard {
    use super::*;
    use starknet::get_caller_address;

    #[starknet::interface]
    trait IReentrancyGuard<TContractState> {
        fn _non_reentrant_before(ref self: TContractState);
        fn _non_reentrant_after(ref self: TContractState);
    }

    #[starknet::contract]
    mod ReentrancyGuardImpl {
        use super::*;

        #[storage]
        struct Storage {
            // Maps caller address to reentrancy status
            _reentrancy_status: LegacyMap<ContractAddress, bool>,
        }

        #[event]
        #[derive(Drop, starknet::Event)]
        enum Event {
            ReentrancyAttempted: ReentrancyAttempted,
        }

        #[derive(Drop, Debug, PartialEq, starknet::Event)]
        pub struct ReentrancyAttempted {
            pub caller: ContractAddress,
        }

        #[external(v0)]
        impl ReentrancyGuardImpl of super::IReentrancyGuard<ContractState> {
            fn _non_reentrant_before(ref self: ContractState) {
                let caller = get_caller_address();
                let is_reentering = self._reentrancy_status.read(caller);
                assert(!is_reentering, 'ReentrancyGuard: reentrant call');
                self._reentrancy_status.write(caller, true);
            }

            fn _non_reentrant_after(ref self: ContractState) {
                let caller = get_caller_address();
                self._reentrancy_status.write(caller, false);
            }
        }
    }
} 