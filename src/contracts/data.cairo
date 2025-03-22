use starknet::ContractAddress;


#[starknet::interface]
pub trait IAttensysUserData<TContractState> {
    fn create_name(ref self: TContractState, name: ByteArray, uri: ByteArray);
    fn name_exists(self: @TContractState, name: ByteArray) -> bool;
    fn get_all_users(self: @TContractState) -> Array<AttensysUserData::User>;
    fn get_specific_user(self: @TContractState, user: ContractAddress) -> AttensysUserData::User;
}


#[starknet::contract]
mod AttensysUserData {
    use starknet::{ ContractAddress, get_caller_address };
    use starknet::storage::{ Map, StorageMapReadAccess, StorageMapWriteAccess, Vec, VecTrait, MutableVecTrait };

    #[storage]
    struct Storage {
        user: Map<ContractAddress, User>,
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct User {
        name: ByteArray,
        uri: ByteArray
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        UserProfileCreated: UserProfileCreated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct UserProfileCreated {
        user_address: ContractAddress,
        uri: ByteArray
    }

    #[abi(embed_v0)]
    impl IAttensysUserDataImpl of super::IAttensysUserData<ContractState> {
        fn create_name(ref self: ContractState, name: ByteArray, uri: ByteArray) {

        }
        fn name_exists(self: @ContractState, name: ByteArray) -> bool {

        }
        fn get_all_users(self: @ContractState) -> Array<User> {

        }
        fn get_specific_user(self: @ContractState, user: ContractAddress) -> User {

        }

    }

}