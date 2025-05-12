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
    use core::num::traits::Zero;
    use core::starknet::storage::Map;
    use starknet::{get_caller_address, get_contract_address};
    use super::ContractAddress;

    #[storage]
    struct Storage {
        balances: Map<ContractAddress, u256>,
        attenSysOrganization: ContractAddress,
        attenSysEvent: ContractAddress,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        SponsorDeposited: SponsorDeposited,
        TokenWithdraw: TokenWithdraw,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct SponsorDeposited {
        pub token: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct TokenWithdraw {
        pub token: ContractAddress,
        pub amount: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        organization_contract_address: ContractAddress,
        event_contract_address: ContractAddress,
    ) {
        assert(!organization_contract_address.is_zero(), 'zero address.');
        assert(!event_contract_address.is_zero(), 'zero address.');
        self.attenSysOrganization.write(organization_contract_address);
        self.attenSysEvent.write(event_contract_address);
    }


    #[abi(embed_v0)]
    impl AttenSysSponsorImpl of super::IAttenSysSponsor<ContractState> {
        fn deposit(
            ref self: ContractState,
            sender: ContractAddress,
            token_address: ContractAddress,
            amount: u256,
        ) {
            let caller = get_caller_address();
            assert(
                caller == self.attenSysOrganization.read() || caller == self.attenSysEvent.read(),
                'not an expected caller.',
            );
            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
            let has_transferred = token_dispatcher
                .transferFrom(sender: sender, recipient: get_contract_address(), amount: amount);

            if has_transferred {
                self
                    .emit(
                        Event::SponsorDeposited(
                            SponsorDeposited { token: token_address, amount: amount },
                        ),
                    );
                self.balances.write(token_address, self.balances.read(token_address) + amount)
            }
        }

        fn withdraw(ref self: ContractState, token_address: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            assert(
                caller == self.attenSysOrganization.read() || caller == self.attenSysEvent.read(),
                'not an expected caller.',
            );
            let contract_token_balance = self.balances.read(token_address);
            assert(amount <= contract_token_balance, 'Not enough balance');
            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
            let has_transferred = token_dispatcher.transfer(recipient: caller, amount: amount);

            if has_transferred {
                self
                    .emit(
                        Event::SponsorDeposited(
                            SponsorDeposited { token: token_address, amount: amount },
                        ),
                    );
                self.balances.write(token_address, self.balances.read(token_address) - amount)
            }
        }

        fn get_contract_balance(self: @ContractState, token_address: ContractAddress) -> u256 {
            self.balances.read(token_address)
        }
    }
}
