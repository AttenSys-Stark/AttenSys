use starknet::ContractAddress;


#[starknet::interface]
pub trait IAttensysUserData<TContractState> {
    fn create_name(ref self: TContractState, name: felt252, uri: felt252);
    fn name_exists(self: @TContractState, name: felt252) -> bool;
    fn get_all_users(self: @TContractState) -> Array<AttensysUserData::User>;
    fn get_specific_user(self: @TContractState, user: ContractAddress) -> AttensysUserData::User;
}


#[starknet::contract]
pub mod AttensysUserData {
    use starknet::storage::{Map, MutableVecTrait, StoragePathEntry, Vec, VecTrait};
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    struct Storage {
        users: Vec<User>,
        is_name_taken: Map<felt252, bool>,
        user: Map<ContractAddress, User>,
    }

    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct User {
        pub name: felt252,
        pub uri: felt252,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        UserProfileCreated: UserProfileCreated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct UserProfileCreated {
        user_address: ContractAddress,
        uri: felt252,
    }

    #[abi(embed_v0)]
    impl IAttensysUserDataImpl of super::IAttensysUserData<ContractState> {
        fn create_name(ref self: ContractState, name: felt252, uri: felt252) {
            let caller = get_caller_address();
            let name_map = self.is_name_taken.entry(name);
            assert(name != 0 && uri != 0, 'Invalid name or uri');
            assert(!name_map.read(), 'name already taken');

            name_map.write(true);

            let user: User = User { name, uri };
            self.users.append().write(user);
            self.user.entry(caller).write(user);

            self.emit(UserProfileCreated { user_address: caller, uri });
        }

        fn name_exists(self: @ContractState, name: felt252) -> bool {
            self.is_name_taken.entry(name).read()
        }

        fn get_all_users(self: @ContractState) -> Array<User> {
            let mut users_arr = ArrayTrait::new();
            let users_len = self.users.len();

            let mut index = 0;
            loop {
                if index >= users_len {
                    break;
                }
                let user = self.users.at(index).read();
                users_arr.append(user);
                index += 1;
            }

            users_arr
        }

        fn get_specific_user(self: @ContractState, user: ContractAddress) -> User {
            self.user.entry(user).read()
        }
    }
}
