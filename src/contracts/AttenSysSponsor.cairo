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

#[starknet::interface]
pub trait IUpgradeable<TContractState> {
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}

#[starknet::contract]
pub mod AttenSysSponsor {
    use core::num::traits::Zero;
    use attendsys::contracts::AttenSysSponsor::IERC20DispatcherTrait;
    use attendsys::contracts::AttenSysSponsor::IERC20Dispatcher;
    use super::ContractAddress;
    use starknet::{get_caller_address, get_contract_address, ClassHash, contract_address_const, replace_class_syscall};
    use core::starknet::storage::{Map};
    use starknet::event::EventEmitter;

    #[storage]
    struct Storage {
        balances: Map<ContractAddress, u256>,
        attenSysOrganization: ContractAddress,
        attenSysEvent: ContractAddress,
        admin: ContractAddress,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        SponsorDeposited: SponsorDeposited,
        TokenWithdraw: TokenWithdraw,
        ContractUpgraded: ContractUpgraded,
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

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct ContractUpgraded {
        pub old_class_hash: ClassHash,
        pub new_class_hash: ClassHash,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        organization_contract_address: ContractAddress,
        event_contract_address: ContractAddress,
        admin: ContractAddress,
    ) {
        assert(!organization_contract_address.is_zero(), 'zero address.');
        assert(!event_contract_address.is_zero(), 'zero address.');
        assert(!admin.is_zero(), 'zero address.');
        self.attenSysOrganization.write(organization_contract_address);
        self.attenSysEvent.write(event_contract_address);
        self.admin.write(admin);
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
                        SponsorDeposited { token: token_address, amount: amount }
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
                        TokenWithdraw { token: token_address, amount: amount }
                    );
                self.balances.write(token_address, self.balances.read(token_address) - amount)
            }
        }

        fn get_contract_balance(self: @ContractState, token_address: ContractAddress) -> u256 {
            self.balances.read(token_address)
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of super::IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            let caller = get_caller_address();
            assert(caller == self.admin.read(), 'unauthorized caller');
            
            assert(!new_class_hash.is_zero(), 'New class hash cannot be zero');
            
            let current_class_hash = starknet::syscalls::get_contract_address()
                .class_hash_at(contract_address_const::<0>()).unwrap();
            
            assert(current_class_hash != new_class_hash, 'Cannot upgrade to same class');
            
            replace_class_syscall(new_class_hash).expect('Upgrade failed');
            
            self.emit(ContractUpgraded { 
                old_class_hash: current_class_hash,
                new_class_hash: new_class_hash 
            });
        }
    }
}