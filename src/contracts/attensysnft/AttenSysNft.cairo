use starknet::ContractAddress;

#[starknet::interface]
pub trait IAttenSysNft<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, token_id: u256);
    fn authorize_minter(ref self: TContractState, minter: ContractAddress);
    fn revoke_minter(ref self: TContractState, minter: ContractAddress);
    fn is_authorized_minter(self: @TContractState, minter: ContractAddress) -> bool;
}

#[starknet::contract]
mod AttenSysNft {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use starknet::storage::Map;
    use starknet::{ContractAddress, get_caller_address};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // Hardcoded course contract address
    const ATTENSYS_COURSE_ADDRESS: felt252 =
        0x5390dc11f780b241418e875095cca768ded2a9c1b605af036bf2760bd5bf6ef;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        // Authorized minters mapping
        authorized_minters: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        MinterAuthorized: MinterAuthorized,
        MinterRevoked: MinterRevoked,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MinterAuthorized {
        pub minter: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MinterRevoked {
        pub minter: ContractAddress,
    }

    /// Ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[constructor]
    fn constructor(
        ref self: ContractState,
        base_uri: ByteArray,
        name_: ByteArray,
        symbol: ByteArray,
        owner_: ContractAddress,
    ) {
        self.erc721.initializer(name_, symbol, base_uri);
        self.ownable.initializer(owner_);

        // Authorize the hardcoded course contract address
        let attensys_course: ContractAddress = ATTENSYS_COURSE_ADDRESS.try_into().unwrap();
        self.authorized_minters.write(attensys_course, true);
        self.emit(MinterAuthorized { minter: attensys_course });

        let deployer = get_caller_address();
        self.authorized_minters.write(deployer, true);
        self.emit(MinterAuthorized { minter: deployer });
    }

    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721MixinImpl<ContractState>;

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl AttenSysNft of super::IAttenSysNft<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, token_id: u256) {
            let caller = get_caller_address();
            // Check if caller is authorized to mint
            assert(self.authorized_minters.read(caller), 'Unauthorized minter');
            self.erc721.mint(recipient, token_id);
        }

        fn authorize_minter(ref self: ContractState, minter: ContractAddress) {
            // Only contract owner can authorize new minters
            self.ownable.assert_only_owner();
            self.authorized_minters.write(minter, true);
            self.emit(MinterAuthorized { minter });
        }

        /// Revoke minter authorization, only owner can call this
        fn revoke_minter(ref self: ContractState, minter: ContractAddress) {
            self.ownable.assert_only_owner();
            self.authorized_minters.write(minter, false);
            self.emit(MinterRevoked { minter });
        }

        /// Check if an address is authorized to mint
        fn is_authorized_minter(self: @ContractState, minter: ContractAddress) -> bool {
            self.authorized_minters.read(minter)
        }
    }
}
