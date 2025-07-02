use core::starknet::{ClassHash, ContractAddress};

//to do : return the nft id and token uri in the get function

#[starknet::interface]
pub trait IAttenSysCourse<TContractState> {
    fn create_course(
        ref self: TContractState,
        owner_: ContractAddress,
        accessment_: bool,
        base_uri: ByteArray,
        name_: ByteArray,
        symbol: ByteArray,
        course_ipfs_uri: ByteArray,
        price_: u128,
    ) -> (ContractAddress, u128);
    fn add_replace_course_content(
        ref self: TContractState,
        course_identifier: u128,
        owner_: ContractAddress,
        new_course_uri: ByteArray,
    );
    fn acquire_a_course(ref self: TContractState, course_identifier: u128);
    //untested
    fn finish_course_claim_certification(ref self: TContractState, course_identifier: u128);
    //untested
    fn check_course_completion_status_n_certification(
        self: @TContractState, course_identifier: u128, candidate: ContractAddress,
    ) -> bool;
    fn remove_course(ref self: TContractState, course_identifier: u128);
    fn get_course_infos(
        self: @TContractState, course_identifiers: Array<u128>,
    ) -> Array<AttenSysCourse::Course>;
    fn is_user_taking_course(self: @TContractState, user: ContractAddress, course_id: u128) -> bool;
    fn is_user_certified_for_course(
        self: @TContractState, user: ContractAddress, course_id: u128,
    ) -> bool;
    fn get_all_taken_courses(
        self: @TContractState, user: ContractAddress,
    ) -> Array<AttenSysCourse::Course>;
    fn get_user_completed_courses(self: @TContractState, user: ContractAddress) -> Array<u128>;
    fn get_all_courses_info(self: @TContractState) -> Array<AttenSysCourse::Course>;
    fn get_all_creator_courses(
        self: @TContractState, owner_: ContractAddress,
    ) -> Array<AttenSysCourse::Course>;
    fn get_creator_info(self: @TContractState, creator: ContractAddress) -> AttenSysCourse::Creator;
    fn get_course_nft_contract(self: @TContractState, course_identifier: u128) -> ContractAddress;
    fn transfer_admin(ref self: TContractState, new_admin: ContractAddress);
    fn claim_admin_ownership(ref self: TContractState);
    fn get_admin(self: @TContractState) -> ContractAddress;
    fn get_new_admin(self: @TContractState) -> ContractAddress;
    fn get_total_course_completions(self: @TContractState, course_identifier: u128) -> u128;
    fn ensure_admin(self: @TContractState);
    fn get_suspension_status(self: @TContractState, course_identifier: u128) -> bool;
    fn get_course_approval_status(self: @TContractState, course_identifier: u128) -> bool;
    fn toggle_suspension(ref self: TContractState, course_identifier: u128, suspend: bool);
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
    fn get_price_of_strk_usd(self: @TContractState) -> u128;
    fn get_strk_of_usd(self: @TContractState, usd_price: u128) -> u128;
    fn update_price(ref self: TContractState, course_identifier: u128, new_price: u128);
    fn toggle_course_approval(ref self: TContractState, course_identifier: u128, approve: bool);
    fn creator_withdraw(ref self: TContractState, amount: u128);
    fn init_fee_percent(ref self: TContractState, fee: u128);
    fn admin_withdrawables(ref self: TContractState, amount: u128);
    fn get_creator_withdrawable_amount(self: @TContractState, user: ContractAddress) -> u128;
    fn get_fee_withdrawable_amount(self: @TContractState) -> u128;
    fn get_total_course_sales(self: @TContractState, user: ContractAddress) -> u128;
    fn review(ref self: TContractState, course_identifier: u128);
    fn get_review_status(
        self: @TContractState, course_identifier: u128, user: ContractAddress,
    ) -> bool;
}

//Todo, make a count of the total number of users that finished the course.

#[starknet::interface]
pub trait IAttenSysNft<TContractState> {
    // NFT contract
    fn mint(ref self: TContractState, recipient: ContractAddress, token_id: u256);
}

#[starknet::interface]
pub trait IERC20<TContractState> {
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u128;
    fn balanceOf(self: @TContractState, account: ContractAddress) -> u128;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u128;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transferFrom(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u128) -> bool;
}

#[starknet::contract]
pub mod AttenSysCourse {
    use attendsys::contracts::course::AttenSysCourse::{IERC20Dispatcher, IERC20DispatcherTrait};
    use core::starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use core::starknet::syscalls::deploy_syscall;
    use core::starknet::{
        ClassHash, ContractAddress, contract_address_const, get_caller_address,
        get_contract_address,
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use pragma_lib::abi::{IPragmaABIDispatcher, IPragmaABIDispatcherTrait};
    use pragma_lib::types::{AggregationMode, DataType, PragmaPricesResponse};
    use super::IAttenSysNftDispatcherTrait;


    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    /// Ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    /// Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    // Pragma Oracle address on Sepolia
    const PRAGMA_ORACLE_ADDRESS: felt252 =
        0x36031daa264c24520b11d93af622c848b2499b66b41d611bac95e13cfca131a;
    const KEY: felt252 = 6004514686061859652; // STRK/USD 
    const ORACLE_PRECISION: u128 = 100_000_000;
    const DECIMALS: u128 = 10_00_000_000_000_000_000; // 18 decimals

    const STRK_CONTRACT_ADDRESS: felt252 =
        0x04718f5a0Fc34cC1AF16A1cdee98fFB20C31f5cD61D6Ab07201858f4287c938D;

    #[event]
    #[derive(starknet::Event, Debug, Drop)]
    pub enum Event {
        CourseCreated: CourseCreated,
        CourseReplaced: CourseReplaced,
        CourseCertClaimed: CourseCertClaimed,
        AdminTransferred: AdminTransferred,
        CourseSuspended: CourseSuspended,
        CourseUnsuspended: CourseUnsuspended,
        CourseRemoved: CourseRemoved,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        CoursePriceUpdated: CoursePriceUpdated,
        AcquiredCourse: AcquiredCourse,
        CourseApproved: CourseApproved,
        CourseUnapproved: CourseUnapproved,
    }

    #[derive(starknet::Event, Clone, Debug, Drop)]
    pub struct CourseCreated {
        pub course_identifier: u128,
        pub owner_: ContractAddress,
        pub accessment_: bool,
        pub base_uri: ByteArray,
        pub name_: ByteArray,
        pub symbol: ByteArray,
        pub course_ipfs_uri: ByteArray,
        pub is_approved: bool,
    }

    #[derive(starknet::Event, Clone, Debug, Drop)]
    pub struct CourseReplaced {
        pub course_identifier: u128,
        pub owner_: ContractAddress,
        pub new_course_uri: ByteArray,
    }

    #[derive(starknet::Event, Clone, Debug, Drop)]
    pub struct CourseCertClaimed {
        pub course_identifier: u128,
        pub candidate: ContractAddress,
    }

    #[derive(starknet::Event, Clone, Debug, Drop)]
    pub struct AdminTransferred {
        pub new_admin: ContractAddress,
    }

    #[derive(starknet::Event, Clone, Debug, Drop)]
    pub struct CourseSuspended {
        course_identifier: u128,
    }

    #[derive(starknet::Event, Clone, Debug, Drop)]
    pub struct CourseUnsuspended {
        course_identifier: u128,
    }

    #[derive(starknet::Event, Clone, Debug, Drop)]
    pub struct CourseRemoved {
        course_identifier: u128,
    }

    #[derive(starknet::Event, Clone, Debug, Drop)]
    pub struct CoursePriceUpdated {
        course_identifier: u128,
        new_price: u128,
    }

    #[derive(starknet::Event, Clone, Debug, Drop)]
    pub struct AcquiredCourse {
        course_identifier: u128,
        owner: ContractAddress,
        candidate: ContractAddress,
    }

    #[derive(starknet::Event, Clone, Debug, Drop)]
    pub struct CourseApproved {
        course_identifier: u128,
    }

    #[derive(starknet::Event, Clone, Debug, Drop)]
    pub struct CourseUnapproved {
        course_identifier: u128,
    }

    #[storage]
    struct Storage {
        //save content creator info including all all contents created.
        course_creator_info: Map<ContractAddress, Creator>,
        //saves specific course (course details only), set this when creating course
        specific_course_info_with_identifer: Map<u128, Course>,
        //saves all course info
        all_course_info: Vec<Course>,
        //saves a course completion status after successfully completed a particular course
        completion_status: Map<(ContractAddress, u128), bool>,
        //saves completed courses by user
        completed_courses: Map<ContractAddress, Vec<u128>>,
        //saves identifier tracker
        identifier_tracker: u128,
        //maps, creator's address to an array of struct of all courses created.
        creator_to_all_content: Map<ContractAddress, Vec<Course>>,
        //nft classhash
        hash: ClassHash,
        //admin address
        admin: ContractAddress,
        // address of intended new admin
        intended_new_admin: ContractAddress,
        //saves nft contract address associated to event
        course_nft_contract_address: Map<u128, ContractAddress>,
        //tracks all minted nft id minted by events
        track_minted_nft_id: Map<(u128, ContractAddress), u128>,
        // user to courses
        user_courses: Map<ContractAddress, Vec<Course>>,
        // user_to_course_status to prevent more than once
        user_to_course_status: Map<(ContractAddress, u128), bool>,
        // user is certified on a course status
        is_course_certified: Map<(ContractAddress, u128), bool>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        //amount withdrawable
        withdrawable_amount: Map<ContractAddress, u128>,
        //fee value
        fee_value: u128,
        //withdrawable fee
        fee_withdrawable: u128,
        // total course sales
        total_course_sales: Map<ContractAddress, u128>,
        // review status
        course_review: Map<(ContractAddress, u128), bool>,
    }
    //find a way to keep track of all course identifiers for each owner.
    #[derive(Drop, Serde, starknet::Store)]
    pub struct Creator {
        pub address: ContractAddress,
        pub number_of_courses: u128,
        pub creator_status: bool,
    }

    //consider the idea of having the uri for each course within the course struct.

    #[derive(Drop, Clone, Serde, starknet::Store)]
    pub struct Course {
        pub owner: ContractAddress,
        pub course_identifier: u128,
        pub accessment: bool,
        pub uri: ByteArray,
        pub course_ipfs_uri: ByteArray,
        pub is_suspended: bool,
        pub price: u128,
        pub is_approved: bool,
    }

    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct Uri {
        pub first: felt252,
        pub second: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, _hash: ClassHash) {
        self.admin.write(owner);
        self.hash.write(_hash);
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl IAttenSysCourseImpl of super::IAttenSysCourse<ContractState> {
        fn create_course(
            ref self: ContractState,
            owner_: ContractAddress,
            accessment_: bool,
            base_uri: ByteArray,
            name_: ByteArray,
            symbol: ByteArray,
            course_ipfs_uri: ByteArray,
            price_: u128,
        ) -> (ContractAddress, u128) {
            //make an address zero check
            let identifier_count = self.identifier_tracker.read();
            let current_identifier = identifier_count + 1;
            let mut current_creator_info: Creator = self.course_creator_info.entry(owner_).read();
            if current_creator_info.number_of_courses > 0 {
                assert(owner_ == get_caller_address(), 'not owner');
                current_creator_info.number_of_courses += 1;
            } else {
                current_creator_info.address = owner_;
                current_creator_info.number_of_courses += 1;
                current_creator_info.creator_status = true;
            }

            let mut course_call_data: Course = Course {
                owner: owner_,
                course_identifier: current_identifier,
                accessment: accessment_,
                uri: base_uri.clone(),
                course_ipfs_uri: course_ipfs_uri.clone(),
                is_suspended: false,
                price: price_,
                is_approved: false,
            };

            self
                .all_course_info
                .append()
                .write(
                    Course {
                        owner: owner_,
                        course_identifier: current_identifier,
                        accessment: accessment_,
                        uri: base_uri.clone(),
                        course_ipfs_uri: course_ipfs_uri.clone(),
                        is_suspended: false,
                        price: price_,
                        is_approved: false,
                    },
                );

            self
                .creator_to_all_content
                .entry(owner_)
                .append()
                .write(
                    Course {
                        owner: owner_,
                        course_identifier: current_identifier,
                        accessment: accessment_,
                        uri: base_uri.clone(),
                        course_ipfs_uri: course_ipfs_uri.clone(),
                        is_suspended: false,
                        price: price_,
                        is_approved: false,
                    },
                );
            self.course_creator_info.entry(owner_).write(current_creator_info);
            self
                .specific_course_info_with_identifer
                .entry(current_identifier)
                .write(course_call_data);
            self.identifier_tracker.write(current_identifier);

            // constructor arguments
            let mut constructor_args = array![];
            base_uri.serialize(ref constructor_args);
            name_.serialize(ref constructor_args);
            symbol.serialize(ref constructor_args);
            let contract_address_salt: felt252 = current_identifier.try_into().unwrap();

            //deploy contract
            let (deployed_contract_address, _) = deploy_syscall(
                self.hash.read(), contract_address_salt, constructor_args.span(), false,
            )
                .expect('failed to deploy_syscall');
            self
                .track_minted_nft_id
                .entry((current_identifier, deployed_contract_address))
                .write(1);
            self
                .course_nft_contract_address
                .entry(current_identifier)
                .write(deployed_contract_address);

            self
                .emit(
                    CourseCreated {
                        course_identifier: current_identifier,
                        owner_: owner_,
                        accessment_: accessment_,
                        base_uri: base_uri,
                        name_: name_,
                        symbol: symbol,
                        course_ipfs_uri: course_ipfs_uri,
                        is_approved: false,
                    },
                );
            (deployed_contract_address, current_identifier)
        }

        fn acquire_a_course(ref self: ContractState, course_identifier: u128) {
            let caller = get_caller_address();
            assert(
                !self.user_to_course_status.entry((caller, course_identifier)).read(),
                'already acquired',
            );
            let amount_usd = self
                .specific_course_info_with_identifer
                .entry(course_identifier)
                .price
                .read();

            let amount_in_strk = self.calculate_course_price_in_strk(amount_usd);

            let erc20_dispatcher = IERC20Dispatcher {
                contract_address: STRK_CONTRACT_ADDRESS.try_into().unwrap(),
            };
            erc20_dispatcher
                .transferFrom(
                    get_caller_address(),
                    get_contract_address(),
                    (amount_in_strk * DECIMALS).into(),
                );

            self.user_to_course_status.entry((caller, course_identifier)).write(true);
            let derived_course = self
                .specific_course_info_with_identifer
                .entry(course_identifier)
                .read();
            let course_owner = derived_course.owner;
            self
                .withdrawable_amount
                .entry(course_owner)
                .write(self.withdrawable_amount.entry(course_owner).read() + amount_in_strk.into());
            self.user_courses.entry(caller).append().write(derived_course);
            self
                .total_course_sales
                .entry(course_owner)
                .write(self.total_course_sales.entry(course_owner).read() + 1);
            self.emit(AcquiredCourse { course_identifier, owner: course_owner, candidate: caller });
        }

        fn remove_course(ref self: ContractState, course_identifier: u128) {
            let caller = get_caller_address();
            let mut _owner = self
                .specific_course_info_with_identifer
                .entry(course_identifier)
                .owner
                .read();
            //ensure caller is owner
            assert(caller == _owner, 'not original creator');
            //ensure course exists
            let pre_existing_counter = self.identifier_tracker.read();

            assert(course_identifier <= pre_existing_counter, 'course non-existent');
            assert(course_identifier != 0, 'course non-existent');
            //ensure course is not suspended
            let is_suspended = self.get_suspension_status(course_identifier);
            assert(is_suspended == false, 'Already suspended');

            //create a default value to replace course
            let mut default_course_call_data: Course = Course {
                owner: self.zero_address(),
                course_identifier: 0,
                accessment: false,
                uri: "",
                course_ipfs_uri: "",
                is_suspended: false,
                price: 0,
                is_approved: false,
            };
            //Update with default parameters
            self
                .specific_course_info_with_identifer
                .entry(course_identifier)
                .write(default_course_call_data.clone());

            //run a loop to check if course ID exists in all course info vece, if it does, replace
            //with default.
            if self.all_course_info.len() == 0 {
                self.all_course_info.append().write(default_course_call_data.clone());
            } else {
                for i in 0..self.all_course_info.len() {
                    if self.all_course_info.at(i).read().course_identifier == course_identifier {
                        self.all_course_info.at(i).write(default_course_call_data.clone());
                    }
                };
            }
            //run a loop to update the creator content storage data
            let mut i: u64 = 0;
            let vec_len = self.creator_to_all_content.entry(caller).len();
            loop {
                if i >= vec_len {
                    break;
                }
                let content = self.creator_to_all_content.entry(caller).at(i).read();
                if content.course_identifier == course_identifier {
                    self
                        .creator_to_all_content
                        .entry(caller)
                        .at(i)
                        .write(default_course_call_data.clone());
                }
                i += 1;
            }

            //update current creator info
            let mut current_creator_info: Creator = self.course_creator_info.entry(caller).read();
            current_creator_info.number_of_courses -= 1;

            //update nft contract address
            self.course_nft_contract_address.entry(course_identifier).write(self.zero_address());

            //emit Event
            self.emit(CourseRemoved { course_identifier: course_identifier });
        }


        fn get_all_taken_courses(self: @ContractState, user: ContractAddress) -> Array<Course> {
            let mut course_info_list = array![];
            for i in 0..self.user_courses.entry(user).len() {
                course_info_list.append(self.user_courses.entry(user).at(i).read())
            }

            course_info_list
        }

        // know if user takes a course
        fn is_user_taking_course(
            self: @ContractState, user: ContractAddress, course_id: u128,
        ) -> bool {
            self.user_to_course_status.entry((user, course_id)).read()
        }

        // know if user is certified for a course
        fn is_user_certified_for_course(
            self: @ContractState, user: ContractAddress, course_id: u128,
        ) -> bool {
            self.is_course_certified.entry((user, course_id)).read()
        }


        //from frontend, the idea will be to obtain the previous uri, transfer content from the
        //previous uri to the new uri
        // and write the new uri to state.
        fn add_replace_course_content(
            ref self: ContractState,
            course_identifier: u128,
            owner_: ContractAddress,
            new_course_uri: ByteArray,
        ) {
            let is_suspended = self.get_suspension_status(course_identifier);
            assert(is_suspended == false, 'Already suspended');
            let mut current_course_info: Course = self
                .specific_course_info_with_identifer
                .entry(course_identifier)
                .read();
            let pre_existing_counter = self.identifier_tracker.read();
            assert(course_identifier <= pre_existing_counter, 'course non-existent');
            assert(current_course_info.owner == get_caller_address(), 'not owner');
            current_course_info.uri = new_course_uri.clone();
            self
                .specific_course_info_with_identifer
                .entry(course_identifier)
                .write(current_course_info.clone());
            // let mut copy = array![];
            // let target_index : u64 = 0;
            // for i in 0..self.all_course_info.len() {
            //     copy.append(self.all_course_info.at(i).read());
            // }
            //run a loop to check if course ID exists in all course info vece, if it does, replace
            //the uris.
            for i in 0..self.all_course_info.len() {
                if self.all_course_info.at(i).read().course_identifier == course_identifier {
                    self.all_course_info.at(i).uri.write(new_course_uri.clone());
                    self.all_course_info.at(i).course_ipfs_uri.write(new_course_uri.clone());
                    self
                        .specific_course_info_with_identifer
                        .entry(course_identifier)
                        .course_ipfs_uri
                        .write(new_course_uri.clone());
                    self
                        .specific_course_info_with_identifer
                        .entry(course_identifier)
                        .uri
                        .write(new_course_uri.clone());
                    break;
                };
            }
            //run a loop to update the creator content storage data
            let mut i: u64 = 0;
            let vec_len = self.creator_to_all_content.entry(owner_).len();
            loop {
                if i >= vec_len {
                    break;
                }
                let content = self.creator_to_all_content.entry(owner_).at(i).read();
                if content.course_identifier == course_identifier {
                    self
                        .creator_to_all_content
                        .entry(owner_)
                        .at(i)
                        .course_ipfs_uri
                        .write(new_course_uri.clone());
                    self
                        .creator_to_all_content
                        .entry(owner_)
                        .at(i)
                        .course_ipfs_uri
                        .write(new_course_uri.clone());
                    break;
                }
                i += 1;
            }
            self
                .emit(
                    CourseReplaced {
                        course_identifier: course_identifier,
                        owner_: owner_,
                        new_course_uri: new_course_uri,
                    },
                );
        }


        fn finish_course_claim_certification(ref self: ContractState, course_identifier: u128) {
            //only check for accessment score. that is if there's assesment
            //todo : verifier check, get a value from frontend, confirm the hash if it matches with
            //what is being saved. goal is to avoid fraudulent course claim.
            //todo issue certification. (whitelist address)
            let is_suspended = self.get_suspension_status(course_identifier);
            let taken_status = self
                .user_to_course_status
                .entry((get_caller_address(), course_identifier))
                .read();
            assert(taken_status == true, 'not taken course');
            assert(is_suspended == false, 'Already suspended');
            assert(
                !self.is_course_certified.entry((get_caller_address(), course_identifier)).read(),
                'Already certified',
            );
            self.is_course_certified.entry((get_caller_address(), course_identifier)).write(true);
            self.completion_status.entry((get_caller_address(), course_identifier)).write(true);
            self.completed_courses.entry(get_caller_address()).append().write(course_identifier);
            let nft_contract_address = self
                .course_nft_contract_address
                .entry(course_identifier)
                .read();

            let nft_dispatcher = super::IAttenSysNftDispatcher {
                contract_address: nft_contract_address,
            };

            let nft_id = self
                .track_minted_nft_id
                .entry((course_identifier, nft_contract_address))
                .read();
            nft_dispatcher.mint(get_caller_address(), nft_id.into());
            self
                .track_minted_nft_id
                .entry((course_identifier, nft_contract_address))
                .write(nft_id + 1);
            self
                .emit(
                    CourseCertClaimed {
                        course_identifier: course_identifier, candidate: get_caller_address(),
                    },
                );
        }


        fn check_course_completion_status_n_certification(
            self: @ContractState, course_identifier: u128, candidate: ContractAddress,
        ) -> bool {
            self.completion_status.entry((candidate, course_identifier)).read()
        }

        fn get_course_infos(
            self: @ContractState, course_identifiers: Array<u128>,
        ) -> Array<Course> {
            let mut course_info_list: Array<Course> = array![];
            for element in course_identifiers {
                let mut data = self.specific_course_info_with_identifer.entry(element).read();
                course_info_list.append(data);
            }
            course_info_list
        }

        fn get_user_completed_courses(self: @ContractState, user: ContractAddress) -> Array<u128> {
            let vec = self.completed_courses.entry(user);
            let mut arr = array![];
            let len = vec.len();
            let mut i: u64 = 0;
            loop {
                if i >= len {
                    break;
                }
                if let Option::Some(element) = vec.get(i) {
                    arr.append(element.read());
                }
                i += 1;
            }
            arr
        }

        fn get_all_courses_info(self: @ContractState) -> Array<Course> {
            let mut arr = array![];
            for i in 0..self.all_course_info.len() {
                arr.append(self.all_course_info.at(i).read());
            }
            arr
        }

        fn get_all_creator_courses(self: @ContractState, owner_: ContractAddress) -> Array<Course> {
            let vec = self.creator_to_all_content.entry(owner_);
            let mut arr = array![];
            let len = vec.len();
            let mut i: u64 = 0;
            loop {
                if i >= len {
                    break;
                }
                if let Option::Some(element) = vec.get(i) {
                    arr.append(element.read());
                }
                i += 1;
            }
            arr
        }

        fn get_creator_info(self: @ContractState, creator: ContractAddress) -> Creator {
            self.course_creator_info.entry(creator).read()
        }

        fn get_course_nft_contract(
            self: @ContractState, course_identifier: u128,
        ) -> ContractAddress {
            self.course_nft_contract_address.entry(course_identifier).read()
        }

        fn transfer_admin(ref self: ContractState, new_admin: ContractAddress) {
            assert(new_admin != self.zero_address(), 'zero address not allowed');
            assert(get_caller_address() == self.admin.read(), 'unauthorized caller');

            self.intended_new_admin.write(new_admin);
            self.emit(AdminTransferred { new_admin: new_admin });
        }

        fn claim_admin_ownership(ref self: ContractState) {
            assert(get_caller_address() == self.intended_new_admin.read(), 'unauthorized caller');

            self.admin.write(self.intended_new_admin.read());
            self.intended_new_admin.write(self.zero_address());
        }

        fn get_admin(self: @ContractState) -> ContractAddress {
            self.admin.read()
        }

        fn get_new_admin(self: @ContractState) -> ContractAddress {
            self.intended_new_admin.read()
        }

        fn get_total_course_completions(self: @ContractState, course_identifier: u128) -> u128 {
            let nft_contract_address = self
                .course_nft_contract_address
                .entry(course_identifier)
                .read();
            let next_nft_id = self
                .track_minted_nft_id
                .entry((course_identifier, nft_contract_address))
                .read();

            if next_nft_id <= 1 {
                0
            } else {
                next_nft_id - 1
            }
        }
        fn ensure_admin(self: @ContractState) {
            let caller = get_caller_address();
            assert(caller == self.get_admin(), 'Not admin');
        }

        fn get_suspension_status(self: @ContractState, course_identifier: u128) -> bool {
            self.specific_course_info_with_identifer.entry(course_identifier).is_suspended.read()
        }

        fn get_course_approval_status(self: @ContractState, course_identifier: u128) -> bool {
            self.specific_course_info_with_identifer.entry(course_identifier).is_approved.read()
        }

        fn toggle_suspension(ref self: ContractState, course_identifier: u128, suspend: bool) {
            self.ensure_admin();

            let course = self.specific_course_info_with_identifer.entry(course_identifier).read();

            if course.is_suspended != suspend {
                self
                    .specific_course_info_with_identifer
                    .entry(course_identifier)
                    .is_suspended
                    .write(suspend);

                if suspend {
                    self.emit(CourseSuspended { course_identifier });
                } else {
                    self.emit(CourseUnsuspended { course_identifier });
                }
            }
        }
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            // Replace the class hash upgrading the contract
            self.upgradeable.upgrade(new_class_hash);
        }

        fn get_price_of_strk_usd(self: @ContractState) -> u128 {
            self.internal_get_price_of_strk_usd()
        }

        fn get_strk_of_usd(self: @ContractState, usd_price: u128) -> u128 {
            self.calculate_course_price_in_strk(usd_price)
        }

        fn update_price(ref self: ContractState, course_identifier: u128, new_price: u128) {
            let caller = get_caller_address();
            let current_creator_info: Creator = self.course_creator_info.entry(caller).read();
            assert(current_creator_info.creator_status == true, 'not creator');

            let mut course = self
                .specific_course_info_with_identifer
                .entry(course_identifier)
                .read();
            course.price = new_price;
            self.specific_course_info_with_identifer.entry(course_identifier).write(course);
            self.emit(CoursePriceUpdated { course_identifier, new_price });
        }

        fn toggle_course_approval(ref self: ContractState, course_identifier: u128, approve: bool) {
            self.ensure_admin();

            let mut course = self
                .specific_course_info_with_identifer
                .entry(course_identifier)
                .read();

            if course.is_approved != approve {
                let owner = course.owner;
                course.is_approved = approve;
                self
                    .specific_course_info_with_identifer
                    .entry(course_identifier)
                    .write(course.clone());

                // Update in all_course_info
                for i in 0..self.all_course_info.len() {
                    let mut course_info = self.all_course_info.at(i).read();
                    if course_info.course_identifier == course_identifier {
                        course_info.is_approved = approve;
                        self.all_course_info.at(i).write(course_info.clone());
                    }
                }

                // Update in creator_to_all_content
                let mut i: u64 = 0;
                let vec_len = self.creator_to_all_content.entry(owner).len();
                loop {
                    if i >= vec_len {
                        break;
                    }
                    let mut content = self.creator_to_all_content.entry(owner).at(i).read();
                    if content.course_identifier == course_identifier {
                        content.is_approved = approve;
                        self.creator_to_all_content.entry(owner).at(i).write(content.clone());
                    }
                    i += 1;
                }

                if approve {
                    self.emit(CourseApproved { course_identifier });
                } else {
                    self.emit(CourseUnapproved { course_identifier });
                }
            }
        }

        fn creator_withdraw(ref self: ContractState, amount: u128) {
            let caller = get_caller_address();
            let token_dispatcher = IERC20Dispatcher {
                contract_address: STRK_CONTRACT_ADDRESS.try_into().unwrap(),
            };
            let contract_token_balance = token_dispatcher.balanceOf(get_contract_address());
            assert(self.withdrawable_amount.entry(caller).read() > 0, 'not admin');
            assert(amount <= contract_token_balance, 'Not enough balance');
            let creator_balance = self.withdrawable_amount.entry(caller).read();
            assert(amount <= creator_balance, 'Not enough balance');
            let fee = amount * self.fee_value.read() / 100;
            let withdrawable_less_fee = amount - fee;
            self.fee_withdrawable.write(self.fee_withdrawable.read() + fee);
            let has_transferred = token_dispatcher
                .transfer(recipient: caller, amount: (withdrawable_less_fee * DECIMALS).into());
            if has_transferred {
                self
                    .withdrawable_amount
                    .entry(caller)
                    .write(self.withdrawable_amount.entry(caller).read() - amount);
            }
        }

        fn init_fee_percent(ref self: ContractState, fee: u128) {
            assert(fee > 0, 'fee cannot be zero');
            assert(fee <= 100, 'fee cannot be > 100');
            assert(get_caller_address() == self.admin.read(), 'unauthorized caller');
            self.fee_value.write(fee);
        }

        fn admin_withdrawables(ref self: ContractState, amount: u128) {
            assert(amount > 0, 'amount cannot be zero');
            assert(amount <= self.fee_withdrawable.read(), 'Not enough balance');
            assert(get_caller_address() == self.admin.read(), 'unauthorized caller');
            let token_dispatcher = IERC20Dispatcher {
                contract_address: STRK_CONTRACT_ADDRESS.try_into().unwrap(),
            };
            let has_transferred = token_dispatcher
                .transfer(recipient: get_caller_address(), amount: (amount * DECIMALS).into());
            if has_transferred {
                self.fee_withdrawable.write(self.fee_withdrawable.read() - amount);
            }
        }
        fn get_creator_withdrawable_amount(self: @ContractState, user: ContractAddress) -> u128 {
            self.withdrawable_amount.entry(user).read()
        }
        fn get_fee_withdrawable_amount(self: @ContractState) -> u128 {
            self.fee_withdrawable.read()
        }
        fn get_total_course_sales(self: @ContractState, user: ContractAddress) -> u128 {
            self.total_course_sales.read(user)
        }

        fn review(ref self: ContractState, course_identifier: u128) {
            let caller = get_caller_address();
            assert(
                self.user_to_course_status.entry((caller, course_identifier)).read(),
                'not acquired',
            );
            assert(
                !self.course_review.entry((caller, course_identifier)).read(), 'already reviewed',
            );
            self.course_review.entry((caller, course_identifier)).write(true);
        }

        fn get_review_status(
            self: @ContractState, course_identifier: u128, user: ContractAddress,
        ) -> bool {
            self.course_review.entry((user, course_identifier)).read()
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn zero_address(self: @ContractState) -> ContractAddress {
            contract_address_const::<0>()
        }

        fn internal_get_price_of_strk_usd(self: @ContractState) -> u128 {
            let asset_data_type = DataType::SpotEntry(KEY);
            let oracle = IPragmaABIDispatcher {
                contract_address: PRAGMA_ORACLE_ADDRESS.try_into().unwrap(),
            };
            let oracle_response = oracle.get_data(asset_data_type, AggregationMode::Median(()));
            let price_of_strk_usd = oracle_response.price;
            price_of_strk_usd
        }


        fn calculate_course_price_in_strk(self: @ContractState, usd_price: u128) -> u128 {
            let strk_price = self
                .internal_get_price_of_strk_usd(); // returns 13572066 for $0.13572066

            // If we want 25 USD worth of STRK:
            // 25 * 10^8 / 13572066 = number of STRK needed
            let scaled_amount = usd_price * ORACLE_PRECISION;

            // Round up division
            if scaled_amount % strk_price == 0 {
                scaled_amount / strk_price
            } else {
                (scaled_amount / strk_price) + 1
            }
        }
    }
}

