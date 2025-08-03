use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC20<TContractState> {
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    fn balanceOf(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transferFrom(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
}

#[starknet::interface]
pub trait IAttenSysSponsor<TContractState> {
    fn deposit(
        ref self: TContractState,
        sender: ContractAddress,
        token_address: ContractAddress,
        amount: u256,
    );
    fn withdraw(ref self: TContractState, token_address: ContractAddress, amount: u256);
    fn get_contract_balance(self: @TContractState, token_address: ContractAddress) -> u256;
}

#[starknet::contract]
pub mod AttenSysSponsor {
    use attendsys::contracts::sponsor::AttenSysSponsor::{IERC20Dispatcher, IERC20DispatcherTrait};
    use attendsys::contracts::validation::input_validation::InputValidation;
    use attendsys::contracts::validation::safe_math::SafeMath;
    use core::num::traits::Zero;
    use core::starknet::storage::Map;
    use starknet::{get_caller_address, get_contract_address};
    use super::ContractAddress;

    #[storage]
    struct Storage {
        balances: Map<ContractAddress, u256>,
        attenSysOrganization: ContractAddress,
        attenSysEvent: ContractAddress,
        // Reentrancy protection
        _reentrancy_status: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        SponsorDeposited: SponsorDeposited,
        TokenWithdraw: TokenWithdraw,
        ReentrancyAttempted: ReentrancyAttempted,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct SponsorDeposited {
        pub token: ContractAddress,
        pub amount: u256,
        pub sender: ContractAddress,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct TokenWithdraw {
        pub token: ContractAddress,
        pub amount: u256,
        pub recipient: ContractAddress,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct ReentrancyAttempted {
        pub caller: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        organization_contract_address: ContractAddress,
        event_contract_address: ContractAddress,
    ) {
        // Input validation
        InputValidation::validate_non_zero_address(organization_contract_address);
        InputValidation::validate_non_zero_address(event_contract_address);
        InputValidation::validate_not_same_address(
            organization_contract_address, event_contract_address,
        );
        self.attenSysOrganization.write(organization_contract_address);
        self.attenSysEvent.write(event_contract_address);
    }

    #[abi(embed_v0)]
    impl AttenSysSponsorImpl of super::IAttenSysSponsor<ContractState> {
        // Reentrancy protection functions
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
        fn deposit(
            ref self: ContractState,
            sender: ContractAddress,
            token_address: ContractAddress,
            amount: u256,
        ) {
            // Input validation
            InputValidation::validate_non_zero_address(sender);
            InputValidation::validate_non_zero_address(token_address);
            InputValidation::validate_amount_not_zero_u256(amount);

            let caller = get_caller_address();
            InputValidation::validate_non_zero_address(caller);
            let org_addr = self.attenSysOrganization.read();
            let event_addr = self.attenSysEvent.read();
            assert(caller == org_addr || caller == event_addr, 'No withdrawable balance');

            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
            let has_transferred = token_dispatcher
                .transferFrom(sender: sender, recipient: get_contract_address(), amount: amount);

            if has_transferred {
                // Update state (Effects)
                let current_balance = self.balances.read(token_address);
                let new_balance = SafeMath::safe_add_u256(current_balance, amount);
                self.balances.write(token_address, new_balance);

                // Emit event (Interactions)
                self.emit(
                    Event::SponsorDeposited(
                        SponsorDeposited { 
                            token: token_address, 
                            amount: amount,
                            sender: sender,
                        },
                    ),
                );
            }
        }

        fn withdraw(ref self: ContractState, token_address: ContractAddress, amount: u256) {
            // Reentrancy protection
            self._non_reentrant_before();

            // Input validation (Checks)
            InputValidation::validate_non_zero_address(token_address);
            InputValidation::validate_amount_not_zero_u256(amount);

            let caller = get_caller_address();
            InputValidation::validate_non_zero_address(caller);
            let org_addr = self.attenSysOrganization.read();
            let event_addr = self.attenSysEvent.read();
            assert(caller == org_addr || caller == event_addr, 'No withdrawable balance');

            let contract_token_balance = self.balances.read(token_address);
            InputValidation::validate_sufficient_balance_u256(contract_token_balance, amount);

            // Update state before external call (Effects)
            let new_balance = SafeMath::safe_sub_u256(contract_token_balance, amount);
            self.balances.write(token_address, new_balance);

            // External call (Interactions)
            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
            let has_transferred = token_dispatcher.transfer(recipient: caller, amount: amount);

            // Verify transfer success
            assert(has_transferred, 'Token transfer failed');

            // Emit event
            self.emit(
                Event::TokenWithdraw(
                    TokenWithdraw { 
                        token: token_address, 
                        amount: amount,
                        recipient: caller,
                    },
                ),
            );

            // Clear reentrancy protection
            self._non_reentrant_after();
        }

        fn get_contract_balance(self: @ContractState, token_address: ContractAddress) -> u256 {
            self.balances.read(token_address)
        }
    }
}
