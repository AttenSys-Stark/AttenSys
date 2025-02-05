use core::starknet::{ContractAddress};

#[starknet::interface]
pub trait IAttenSysOrg<TContractState> {
    fn create_org_profile(ref self: TContractState, org_name: ByteArray, org_ipfs_uri: ByteArray);
    fn add_instructor_to_org(
        ref self: TContractState, instructor: Array<ContractAddress>, org_name: ByteArray
    );
    fn remove_instructor_from_org(ref self: TContractState, instructor: ContractAddress);
    fn create_bootcamp(
        ref self: TContractState,
        org_name: ByteArray,
        bootcamp_name: ByteArray,
        nft_name: ByteArray,
        nft_symbol: ByteArray,
        nft_uri: ByteArray,
        num_of_class_to_create: u256,
        bootcamp_ipfs_uri: ByteArray
    );
    fn add_active_meet_link(
        ref self: TContractState,
        meet_link: ByteArray,
        bootcamp_id: u64,
        is_instructor: bool,
        org_address: ContractAddress
    );
    fn add_uploaded_video_link(
        ref self: TContractState,
        video_link: ByteArray,
        is_instructor: bool,
        org_address: ContractAddress,
        bootcamp_id: u64
    );
    fn register_for_bootcamp(
        ref self: TContractState,
        org_: ContractAddress,
        instructor_: ContractAddress,
        bootcamp_id: u64
    );
    fn approve_registration(
        ref self: TContractState, student_address: ContractAddress, bootcamp_id: u64
    );
    fn mark_attendance_for_a_class(
        ref self: TContractState, org_: ContractAddress, instructor_: ContractAddress, class_id: u64
    );
    fn batch_certify_students(
        ref self: TContractState,
        org_: ContractAddress,
        class_id: u64,
        students: Array<ContractAddress>
    );
    fn setSponsorShipAddress(ref self: TContractState, sponsor_contract_address: ContractAddress);
    fn sponsor_organization(
        ref self: TContractState, organization: ContractAddress, uri: ByteArray, amt: u256
    );
    fn withdraw_sponsorship_fund(ref self: TContractState, amt: u256);
    fn get_bootcamp_active_meet_link(
        self: @TContractState, org_: ContractAddress, bootcamp_id: u64
    ) -> ByteArray;
    fn get_bootcamp_uploaded_video_link(
        self: @TContractState, org_: ContractAddress, bootcamp_id: u64
    ) -> Array<ByteArray>;
    fn get_all_registration_request(
        self: @TContractState, org_: ContractAddress
    ) -> Array<AttenSysOrg::Student>;
    fn get_org_instructors(
        self: @TContractState, org_: ContractAddress
    ) -> Array<AttenSysOrg::Instructor>;
    fn get_all_org_bootcamps(
        self: @TContractState, org_: ContractAddress
    ) -> Array<AttenSysOrg::Bootcamp>;
    fn get_all_bootcamps_on_platform(self: @TContractState) -> Array<AttenSysOrg::Bootcamp>;
    fn get_all_org_classes(
        self: @TContractState, org_: ContractAddress
    ) -> Array<AttenSysOrg::Class>;
    fn get_instructor_org_classes(
        self: @TContractState, org_: ContractAddress, instructor: ContractAddress
    ) -> Array<AttenSysOrg::Class>;
    fn get_org_info(self: @TContractState, org_: ContractAddress) -> AttenSysOrg::Organization;
    fn get_all_org_info(self: @TContractState) -> Array<AttenSysOrg::Organization>;
    fn get_student_info(self: @TContractState, student_: ContractAddress) -> AttenSysOrg::Student;
    fn get_student_classes(
        self: @TContractState, student: ContractAddress
    ) -> Array<AttenSysOrg::Class>;
    fn get_instructor_part_of_org(self: @TContractState, instructor: ContractAddress) -> bool;
    fn get_instructor_info(
        self: @TContractState, instructor: ContractAddress
    ) -> Array<AttenSysOrg::Instructor>;
    fn get_bootcamp_info(
        self: @TContractState, org_: ContractAddress, bootcamp_id: u64
    ) -> AttenSysOrg::Bootcamp;
}

// Events

//The contract
#[starknet::contract]
pub mod AttenSysOrg {
    use starknet::event::EventEmitter;
    use core::starknet::{ContractAddress, ClassHash, get_caller_address, syscalls::deploy_syscall};
    use core::starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
        MutableVecTrait
    };
    use core::num::traits::Zero;
    use attendsys::contracts::AttenSysSponsor::IAttenSysSponsorDispatcherTrait;
    use attendsys::contracts::AttenSysSponsor::IAttenSysSponsorDispatcher;


    #[storage]
    struct Storage {
        // save an organization profile and return info when needed.
        organization_info: Map::<ContractAddress, Organization>,
        // save all organization info
        all_org_info: Vec<Organization>,
        // save all bootcamps
        all_bootcamps_created: Vec<Bootcamp>,
        // status of org creator address
        created_status: Map::<ContractAddress, bool>,
        // org to balance_of_sponsorship
        org_to_balance_of_sponsorship: Map::<ContractAddress, u256>,
        // save instructors of org in an array
        org_to_instructors: Map::<ContractAddress, Vec<Instructor>>,
        // save bootcamps of org in an array
        org_to_bootcamps: Map::<ContractAddress, Vec<Bootcamp>>,
        // org to uploaded ipfs video links
        org_to_uploaded_videos_link: Map::<(ContractAddress, u64), Vec<ByteArray>>,
        //validate that an instructor is associated to an org
        instructor_part_of_org: Map::<(ContractAddress, ContractAddress), bool>,
        // instructor as key
        instructor_key_to_info: Map::<ContractAddress, Vec<Instructor>>,
        //maps org and instructor to classes
        org_instructor_classes: Map::<(ContractAddress, ContractAddress), Vec<Class>>,
        // track the number of classes a single student has registered for.
        student_to_classes: Map::<ContractAddress, Vec<Class>>,
        // update and retrieve students info
        student_info: Map::<ContractAddress, Student>,
        //saves attendance status of students
        student_attendance_status: Map::<(ContractAddress, u64), bool>,
        //saves attendance status of students
        inst_student_status: Map<ContractAddress, Map<ContractAddress, bool>>,
        //cerified course, student ---> true
        certify_student: Map::<(u64, ContractAddress), bool>,
        //nft classhash
        hash: ClassHash,
        // the currency used on the platform
        token_address: ContractAddress,
        // sponsorship contract address
        sponsorship_contract_address: ContractAddress,
        // AttenSys Admin
        admin: ContractAddress,
        // map org to all requested registration
        org_to_requests: Map<ContractAddress, Vec<Student>>,
    }

    //find a way to keep track of all course identifiers for each owner.
    #[derive(Drop, Serde, starknet::Store)]
    pub struct Organization {
        pub address_of_org: ContractAddress,
        pub org_name: ByteArray,
        pub number_of_instructors: u256,
        pub number_of_students: u256,
        pub number_of_all_classes: u256,
        pub number_of_all_bootcamps: u256,
        pub org_ipfs_uri: ByteArray,
        pub total_sponsorship_fund: u256
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct Bootcamp {
        pub bootcamp_id: u256,
        pub address_of_org: ContractAddress,
        pub org_name: ByteArray,
        pub bootcamp_name: ByteArray,
        pub number_of_instructors: u256,
        pub number_of_students: u256,
        pub number_of_all_bootcamp_classes: u256,
        pub nft_address: ContractAddress,
        pub bootcamp_ipfs_uri: ByteArray,
        pub active_meet_link: ByteArray
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct Instructor {
        pub address_of_instructor: ContractAddress,
        pub num_of_classes: u256,
        pub name_of_org: ByteArray,
        pub organization_address: ContractAddress,
    }

    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct Class {
        pub address_of_org: ContractAddress,
        pub instructor: ContractAddress,
        pub num_of_reg_students: u32,
        pub active_status: bool,
        pub bootcamp_id: u256
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct Student {
        pub address_of_student: ContractAddress,
        pub num_of_bootcamps_registered_for: u256,
        pub registered: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Sponsor: Sponsor,
        Withdrawn: Withdrawn,
        OrganizationProfile: OrganizationProfile,
        InstructorAddedToOrg: InstructorAddedToOrg,
        InstructorRemovedFromOrg: InstructorRemovedFromOrg,
        BootCampCreated: BootCampCreated,
        ActiveMeetLinkAdded: ActiveMeetLinkAdded,
        VideoLinkUploaded: VideoLinkUploaded,
        BootcampRegistration: BootcampRegistration,
        RegistrationApproved: RegistrationApproved,
        AttendanceMarked: AttendanceMarked,
        StudentsCertified: StudentsCertified,
        SponsorshipAddressSet: SponsorshipAddressSet,
        OrganizationSponsored: OrganizationSponsored,
        SponsorshipFundWithdrawn: SponsorshipFundWithdrawn
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
    pub struct OrganizationProfile {
        pub org_name: ByteArray,
        pub org_ipfs_uri: ByteArray,
        //     #[key]
    //     pub organization: ContractAddress
    // }
    }

    #[derive(Drop, starknet::Event)]
    pub struct InstructorAddedToOrg {
        pub org_name: ByteArray,
        #[key]
        pub instructor: Array<ContractAddress>
    }

    #[derive(Drop, starknet::Event)]
    pub struct InstructorRemovedFromOrg {
        pub instructor_addr: ContractAddress,
        pub org_owner: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    pub struct BootCampCreated {
        pub org_name: ByteArray,
        pub bootcamp_name: ByteArray,
        pub nft_name: ByteArray,
        pub nft_symbol: ByteArray,
        pub nft_uri: ByteArray,
        pub num_of_classes: u256,
        pub bootcamp_ipfs_uri: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ActiveMeetLinkAdded {
        pub meet_link: ByteArray,
        pub bootcamp_id: u64,
        pub is_instructor: bool,
        pub org_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct VideoLinkUploaded {
        pub video_link: ByteArray,
        pub is_instructor: bool,
        pub org_address: ContractAddress,
        pub bootcamp_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BootcampRegistration {
        pub org_address: ContractAddress,
        pub instructor_address: ContractAddress,
        pub bootcamp_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RegistrationApproved {
        pub student_address: ContractAddress,
        pub bootcamp_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AttendanceMarked {
        pub org_address: ContractAddress,
        pub instructor_address: ContractAddress,
        pub class_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StudentsCertified {
        pub org_address: ContractAddress,
        pub class_id: u64,
        pub student_addresses: Array<ContractAddress>,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SponsorshipAddressSet {
        pub sponsor_contract_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OrganizationSponsored {
        pub organization_address: ContractAddress,
        pub sponsor_uri: ByteArray,
        pub sponsorship_amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SponsorshipFundWithdrawn {
        pub withdrawal_amount: u256,
    }


    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        class_hash: ClassHash,
        _token_address: ContractAddress,
        sponsorship_contract_address: ContractAddress
    ) {
        self.hash.write(class_hash);
        self.token_address.write(_token_address);
        self.sponsorship_contract_address.write(sponsorship_contract_address);
        self.admin.write(admin);
    }

    #[abi(embed_v0)]
    impl IAttenSysOrgImpl of super::IAttenSysOrg<ContractState> {
        //ability to create organization profile, each org info should be saved properly, use
        //mappings and structs where necessary
        fn create_org_profile(
            ref self: ContractState, org_name: ByteArray, org_ipfs_uri: ByteArray
        ) {
            //check that the caller address has an organization created before
            let creator = get_caller_address();
            let status: bool = self.created_status.entry(creator).read();
            if !status {
                self.created_status.entry(creator).write(true);

                // create organization and update to an address
                let org_call_data: Organization = Organization {
                    address_of_org: creator,
                    org_name: org_name.clone(),
                    number_of_instructors: 0,
                    number_of_students: 0,
                    number_of_all_classes: 0,
                    number_of_all_bootcamps: 0,
                    org_ipfs_uri: org_ipfs_uri.clone(),
                    total_sponsorship_fund: 0,
                };

                let uri = org_ipfs_uri.clone();

                self.all_org_info.append().write(org_call_data);
                self
                    .organization_info
                    .entry(creator)
                    .write(
                        Organization {
                            address_of_org: creator,
                            org_name: org_name.clone(),
                            number_of_instructors: 0,
                            number_of_students: 0,
                            number_of_all_classes: 0,
                            number_of_all_bootcamps: 0,
                            org_ipfs_uri: org_ipfs_uri,
                            total_sponsorship_fund: 0,
                        }
                    );
                let orginization_name = org_name.clone();

                self.emit(OrganizationProfile { org_name: orginization_name, org_ipfs_uri: uri });
                // add the organization creator as an instructor
                add_instructor_to_org(ref self, creator, creator, org_name);
            } else {
                panic!("created an organization.");
            }
        }

        // add array of instructor to an organization
        fn add_instructor_to_org(
            ref self: ContractState, instructor: Array<ContractAddress>, org_name: ByteArray
        ) {
            let caller = get_caller_address();
            let status: bool = self.created_status.entry(caller).read();
            // confirm that the caller is associated an organization
            if status {
                for i in 0
                    ..instructor
                        .len() {
                            add_instructor_to_org(
                                ref self, caller, *instructor[i], org_name.clone()
                            );
                        };
                self
                    .emit(
                        InstructorAddedToOrg { org_name: org_name.clone(), instructor: instructor }
                    )
            } else {
                panic!("no organization created.");
            }
        }

        //    remove instructor from an organization.
        fn remove_instructor_from_org(ref self: ContractState, instructor: ContractAddress) {
            assert(!instructor.is_zero(), 'zero address.');
            let caller = get_caller_address();
            let status: bool = self.created_status.entry(caller).read();
            // confirm that the caller is associated an organization
            if status {
                if self.instructor_part_of_org.entry((caller, instructor)).read() {
                    self.instructor_part_of_org.entry((caller, instructor)).write(false);

                    let mut org_call_data: Organization = self
                        .organization_info
                        .entry(caller)
                        .read();
                    org_call_data.number_of_instructors -= 1;
                    self.organization_info.entry(caller).write(org_call_data);
                    let instructors_in_org = self.org_to_instructors.entry(caller);

                    // let mut addresses : Vec<Instructor> = array![];
                    for i in 0
                        ..instructors_in_org
                            .len() {
                                let derived_instructor = self
                                    .org_to_instructors
                                    .entry(caller)
                                    .at(i)
                                    .read()
                                    .address_of_instructor;

                                if instructor == derived_instructor {
                                    // replace the last guy in the spot of the removed instructor
                                    let lastInstructor = self
                                        .org_to_instructors
                                        .entry(caller)
                                        .at(instructors_in_org.len() - 1)
                                        .read();
                                    self
                                        .org_to_instructors
                                        .entry(caller)
                                        .at(i)
                                        .write(lastInstructor);
                                }

                                // Event ng for removing an inspector
                                self
                                    .emit(
                                        InstructorRemovedFromOrg {
                                            instructor_addr: instructor, org_owner: caller
                                        }
                                    )
                            }
                } else {
                    panic!("not an instructor.");
                }
            } else {
                panic!("no organization created.");
            }
        }

        //Add function to allow saving URI's from recorded video #33
        // Add function to allow organization to save the uri obtained from uploading recorded video
        // to ipfs in contract
        fn add_uploaded_video_link(
            ref self: ContractState,
            video_link: ByteArray,
            is_instructor: bool,
            org_address: ContractAddress,
            bootcamp_id: u64
        ) {
            assert(video_link != "", 'empty link');
            let video_link_cp = video_link.clone();
            let mut status: bool = false;
            let caller = get_caller_address();
            let is_instructor_cp = is_instructor.clone();
            if is_instructor {
                status = self.instructor_part_of_org.entry((org_address, caller)).read();
            } else {
                assert(org_address == caller, 'caller not org address');
                status = self.created_status.entry(caller).read();
            }

            // confirm that the caller is associated an organization
            if (status) {
                if is_instructor {
                    self
                        .org_to_uploaded_videos_link
                        .entry((org_address, bootcamp_id))
                        .append()
                        .write(video_link);
                } else {
                    self
                        .org_to_uploaded_videos_link
                        .entry((caller, bootcamp_id))
                        .append()
                        .write(video_link);
                }

                self
                    .emit(
                        VideoLinkUploaded {
                            video_link: video_link_cp,
                            is_instructor: is_instructor_cp,
                            org_address: org_address,
                            bootcamp_id: bootcamp_id
                        }
                    );
            } else {
                panic!("not part of organization.");
            };
        }

        // Must make the admin an instructor to successfully call this
        fn create_bootcamp(
            ref self: ContractState,
            org_name: ByteArray,
            bootcamp_name: ByteArray,
            nft_name: ByteArray,
            nft_symbol: ByteArray,
            nft_uri: ByteArray,
            num_of_class_to_create: u256,
            bootcamp_ipfs_uri: ByteArray
        ) {
            let caller = get_caller_address();
            let status: bool = self.created_status.entry(caller).read();
            // confirm that the caller is associated to an organization
            if (status) {
                // constructor arguments
                let mut constructor_args = array![];
                nft_uri.serialize(ref constructor_args);
                nft_name.serialize(ref constructor_args);
                nft_symbol.serialize(ref constructor_args);
                //deploy contract
                let contract_address_salt: felt252 = caller.into();
                let (deployed_contract_address, _) = deploy_syscall(
                    self.hash.read(), contract_address_salt, constructor_args.span(), false
                )
                    .expect('failed to deploy_syscall');
                let index: u256 = self.org_to_bootcamps.entry(caller).len().into();
                // create bootcamp and update
                let bootcamp_call_data: Bootcamp = Bootcamp {
                    bootcamp_id: index,
                    address_of_org: caller,
                    org_name: org_name.clone(),
                    bootcamp_name: bootcamp_name.clone(),
                    number_of_instructors: 0,
                    number_of_students: 0,
                    number_of_all_bootcamp_classes: 0,
                    nft_address: deployed_contract_address,
                    bootcamp_ipfs_uri: bootcamp_ipfs_uri.clone(),
                    active_meet_link: ""
                };

                //append into the array of bootcamps associated to an organization
                self.org_to_bootcamps.entry(caller).append().write(bootcamp_call_data);
                self
                    .all_bootcamps_created
                    .append()
                    .write(
                        Bootcamp {
                            bootcamp_id: index,
                            address_of_org: caller,
                            org_name: org_name.clone(),
                            bootcamp_name: bootcamp_name.clone(),
                            number_of_instructors: 0,
                            number_of_students: 0,
                            number_of_all_bootcamp_classes: 0,
                            nft_address: deployed_contract_address,
                            bootcamp_ipfs_uri: bootcamp_ipfs_uri.clone(),
                            active_meet_link: ""
                        }
                    );

                // update the number of bootcamps created in an organization
                let mut org_call_data: Organization = self.organization_info.entry(caller).read();
                org_call_data.number_of_all_bootcamps += 1;
                self.organization_info.entry(caller).write(org_call_data);

                // Emmiting a Bootcamp Event
                self
                    .emit(
                        BootCampCreated {
                            org_name: org_name,
                            bootcamp_name: bootcamp_name,
                            nft_name: nft_name,
                            nft_symbol: nft_symbol,
                            nft_uri: nft_uri,
                            num_of_classes: num_of_class_to_create,
                            bootcamp_ipfs_uri: bootcamp_ipfs_uri
                        }
                    );
                //create classes
                create_a_class(ref self, caller, num_of_class_to_create, index);
            } else {
                panic!("no organization created.");
            }
        }

        fn add_active_meet_link(
            ref self: ContractState,
            meet_link: ByteArray,
            bootcamp_id: u64,
            is_instructor: bool,
            org_address: ContractAddress
        ) {
            let mut status: bool = false;
            let caller = get_caller_address();
            let active_link = meet_link.clone();
            let is_instructor_cp = is_instructor.clone();
            if is_instructor {
                status = self.instructor_part_of_org.entry((org_address, caller)).read();
            } else {
                assert(org_address == caller, 'caller not org address');
                status = self.created_status.entry(caller).read();
            }

            // confirm that the caller is associated an organization
            if (status) {
                if is_instructor {
                    let mut bootcamp: Bootcamp = self
                        .org_to_bootcamps
                        .entry(org_address)
                        .at(bootcamp_id)
                        .read();
                    bootcamp.active_meet_link = meet_link;
                    self.org_to_bootcamps.entry(org_address).at(bootcamp_id).write(bootcamp);
                } else {
                    let mut bootcamp: Bootcamp = self
                        .org_to_bootcamps
                        .entry(caller)
                        .at(bootcamp_id)
                        .read();

                    bootcamp.active_meet_link = meet_link;
                    self.org_to_bootcamps.entry(caller).at(bootcamp_id).write(bootcamp);
                }
                // pub meet_link: ByteArray,
                // pub bootcamp_id: u64,
                // pub is_instructor: bool,
                // pub org_address: ContractAddress,

                // Emitting events when a active link is added

                self
                    .emit(
                        ActiveMeetLinkAdded {
                            meet_link: active_link,
                            bootcamp_id: bootcamp_id.clone(),
                            is_instructor: is_instructor_cp,
                            org_address: org_address
                        }
                    );
            } else {
                panic!("not part of organization.");
            };
        }

        fn register_for_bootcamp(
            ref self: ContractState,
            org_: ContractAddress,
            instructor_: ContractAddress,
            bootcamp_id: u64
        ) {
            let caller = get_caller_address();
            let status: bool = self.instructor_part_of_org.entry((org_, instructor_)).read();
            // check that instructor is associated with an organization
            if status {
                let mut bootcamp = self.org_to_bootcamps.entry(org_);
                for i in 0
                    ..bootcamp
                        .len() {
                            if i == bootcamp_id {
                                let mut student: Student = self.student_info.entry(caller).read();
                                student
                                    .num_of_bootcamps_registered_for = student
                                    .num_of_bootcamps_registered_for
                                    + 1;
                                self.student_info.entry(caller).write(student);
                                self
                                    .org_to_requests
                                    .entry(org_)
                                    .append()
                                    .write(
                                        Student {
                                            address_of_student: caller,
                                            num_of_bootcamps_registered_for: self
                                                .student_info
                                                .entry(caller)
                                                .read()
                                                .num_of_bootcamps_registered_for,
                                            registered: false,
                                        }
                                    );
                            }
                        };

                self
                    .emit(
                        BootcampRegistration {
                            org_address: org_,
                            instructor_address: instructor_,
                            bootcamp_id: bootcamp_id
                        }
                    );
            } else {
                panic!("unassociated org N instructor");
            }
        }

        fn approve_registration(
            ref self: ContractState, student_address: ContractAddress, bootcamp_id: u64
        ) {
            let caller = get_caller_address();
            let status: bool = self.created_status.entry(caller).read();

            let mut arr_of_request = array![];
            if status {
                for i in 0
                    ..self
                        .org_to_requests
                        .entry(caller)
                        .len() {
                            if self
                                .org_to_requests
                                .entry(caller)
                                .at(i)
                                .read()
                                .address_of_student == student_address {
                                let mut student = self.org_to_requests.entry(caller).at(i).read();
                                student.registered = true;
                                self.org_to_requests.entry(caller).append().write(student);

                                let mut the_bootcamp: Bootcamp = self
                                    .org_to_bootcamps
                                    .entry(caller)
                                    .at(bootcamp_id)
                                    .read();

                                the_bootcamp.number_of_students = the_bootcamp.number_of_students
                                    + 1;

                                self.org_to_bootcamps.entry(caller).append().write(the_bootcamp);
                            }
                            arr_of_request.append(self.org_to_requests.entry(caller).at(i).read());
                            // update organization and instructor data
                            let mut org = self.organization_info.entry(caller).read();
                            org.number_of_students = org.number_of_students + 1;
                            self.organization_info.entry(caller).write(org);
                        };

                self
                    .emit(
                        RegistrationApproved {
                            student_address: student_address, bootcamp_id: bootcamp_id
                        }
                    );
            } else {
                panic!("no organization created.");
            }
        }

        fn get_all_registration_request(
            self: @ContractState, org_: ContractAddress
        ) -> Array<Student> {
            get_all_registration_request(self, org_)
        }

        fn mark_attendance_for_a_class(
            ref self: ContractState,
            org_: ContractAddress,
            instructor_: ContractAddress,
            class_id: u64
        ) {
            let caller = get_caller_address();
            let mut instructor_class = self
                .org_instructor_classes
                .entry((org_, instructor_))
                .at(class_id)
                .read();
            let reg_status = self.student_attendance_status.entry((caller, class_id)).read();
            assert(instructor_class.active_status, 'not a class');
            assert(!reg_status, 'not registered student');
            self.student_attendance_status.entry((caller, class_id)).write(true);
            self
                .emit(
                    AttendanceMarked {
                        org_address: org_, instructor_address: instructor_, class_id: class_id
                    }
                );
        }

        fn batch_certify_students(
            ref self: ContractState,
            org_: ContractAddress,
            class_id: u64,
            students: Array<ContractAddress>
        ) {
            //only instructor under an organization issues certificate
            //all of the registered students with attendance
            let caller = get_caller_address();
            let is_instructor = self.instructor_part_of_org.entry((org_, caller)).read();
            let num_of_reg_student = self
                .org_instructor_classes
                .entry((org_, caller))
                .at(class_id)
                .read()
                .num_of_reg_students;
            assert(is_instructor, 'not an instructor');
            if num_of_reg_student > 0 {
                for i in 0
                    ..num_of_reg_student {
                        if self.inst_student_status.entry(caller).entry(*students.at(i)).read() {
                            self.certify_student.entry((class_id, *students.at(i))).write(true);
                        }
                    }
            }
            self
                .emit(
                    StudentsCertified {
                        org_address: org_, class_id: class_id, student_addresses: students
                    }
                )
        }

        fn setSponsorShipAddress(
            ref self: ContractState, sponsor_contract_address: ContractAddress
        ) {
            only_admin(ref self);
            assert(!sponsor_contract_address.is_zero(), 'Null address not allowed');
            self.sponsorship_contract_address.write(sponsor_contract_address);
            self.emit(SponsorshipAddressSet { sponsor_contract_address });
        }

        fn sponsor_organization(
            ref self: ContractState, organization: ContractAddress, uri: ByteArray, amt: u256
        ) {
            assert(!organization.is_zero(), 'not an instructor');
            assert(uri.len() > 0, 'uri is empty');

            let status: bool = self.created_status.entry(organization).read();
            if (status) {
                let balanceBefore = self.org_to_balance_of_sponsorship.entry(organization).read();
                self.org_to_balance_of_sponsorship.entry(organization).write(balanceBefore + amt);
                let sponsor_contract_address = self.sponsorship_contract_address.read();
                let token_contract_address = self.token_address.read();
                let sponsor_dispatcher = IAttenSysSponsorDispatcher {
                    contract_address: sponsor_contract_address
                };
                sponsor_dispatcher.deposit(token_contract_address, amt);
                self.emit(Sponsor { amt, uri, organization });
            } else {
                panic!("not an organization");
            }
        }

        fn withdraw_sponsorship_fund(ref self: ContractState, amt: u256) {
            let organization = get_caller_address();
            let status: bool = self.created_status.entry(organization).read();
            if (status) {
                assert(
                    self.org_to_balance_of_sponsorship.entry(organization).read() >= amt,
                    'insufficient funds'
                );
                let contract_address = self.token_address.read();
                let sponsor_contract_address = self.sponsorship_contract_address.read();
                let sponsor_dispatcher = IAttenSysSponsorDispatcher {
                    contract_address: sponsor_contract_address
                };
                sponsor_dispatcher.withdraw(contract_address, amt);

                let balanceBefore = self.org_to_balance_of_sponsorship.entry(organization).read();
                self.org_to_balance_of_sponsorship.entry(organization).write(balanceBefore + amt);
                let contract_address = self.token_address.read();
                let sponsor_dispatcher = IAttenSysSponsorDispatcher { contract_address };
                sponsor_dispatcher.deposit(self.token_address.read(), amt);
                self.emit(Withdrawn { amt, organization });
            } else {
                panic!("not an organization");
            }
        }

        // read functions
        fn get_all_org_bootcamps(self: @ContractState, org_: ContractAddress) -> Array<Bootcamp> {
            let mut arr_of_all_created_bootcamps = array![];

            for i in 0
                ..self
                    .org_to_bootcamps
                    .entry(org_)
                    .len() {
                        arr_of_all_created_bootcamps
                            .append(self.org_to_bootcamps.entry(org_).at(i).read());
                    };

            arr_of_all_created_bootcamps
        }

        fn get_bootcamp_active_meet_link(
            self: @ContractState, org_: ContractAddress, bootcamp_id: u64
        ) -> ByteArray {
            let bootcamp: Bootcamp = self.org_to_bootcamps.entry(org_).at(bootcamp_id).read();
            bootcamp.active_meet_link
        }

        fn get_bootcamp_uploaded_video_link(
            self: @ContractState, org_: ContractAddress, bootcamp_id: u64
        ) -> Array<ByteArray> {
            let mut arr_of_all_uploaded_bootcamps_link = array![];

            for i in 0
                ..self
                    .org_to_uploaded_videos_link
                    .entry((org_, bootcamp_id))
                    .len() {
                        arr_of_all_uploaded_bootcamps_link
                            .append(
                                self
                                    .org_to_uploaded_videos_link
                                    .entry((org_, bootcamp_id))
                                    .at(i)
                                    .read()
                            );
                    };
            arr_of_all_uploaded_bootcamps_link
        }

        // read functions
        fn get_all_bootcamps_on_platform(self: @ContractState) -> Array<Bootcamp> {
            let mut arr_of_all_created_bootcamps_on_platform = array![];

            for i in 0
                ..self
                    .all_bootcamps_created
                    .len() {
                        arr_of_all_created_bootcamps_on_platform
                            .append(self.all_bootcamps_created.at(i).read());
                    };

            arr_of_all_created_bootcamps_on_platform
        }

        // read functions
        fn get_all_org_classes(self: @ContractState, org_: ContractAddress) -> Array<Class> {
            let mut arr_of_org = array![];
            let mut arr_of_instructors = array![];
            let mut arr_of_all_created_classes = array![];

            for i in 0
                ..self
                    .all_org_info
                    .len() {
                        // let i_u32: u32 = i.try_into().unwrap();
                        arr_of_org.append(self.all_org_info.at(i).read());
                        let i_u32: u32 = i.try_into().unwrap();

                        for j in 0
                            ..self
                                .org_to_instructors
                                .entry(*arr_of_org.at(i_u32).address_of_org)
                                .len() {
                                    let j_u32: u32 = j.try_into().unwrap();
                                    arr_of_instructors
                                        .append(
                                            self
                                                .org_to_instructors
                                                .entry(*arr_of_org.at(i_u32).address_of_org)
                                                .at(j)
                                                .read()
                                        );

                                    for k in 0
                                        ..self
                                            .org_instructor_classes
                                            .entry(
                                                (
                                                    *arr_of_org.at(i_u32).address_of_org,
                                                    *arr_of_instructors
                                                        .at(j_u32)
                                                        .address_of_instructor
                                                )
                                            )
                                            .len() {
                                                arr_of_all_created_classes
                                                    .append(
                                                        self
                                                            .org_instructor_classes
                                                            .entry(
                                                                (
                                                                    *arr_of_org
                                                                        .at(i_u32)
                                                                        .address_of_org,
                                                                    *arr_of_instructors
                                                                        .at(j_u32)
                                                                        .address_of_instructor
                                                                )
                                                            )
                                                            .at(k)
                                                            .read()
                                                    );
                                            }
                                }
                    };

            arr_of_all_created_classes
        }

        fn get_student_classes(self: @ContractState, student: ContractAddress) -> Array<Class> {
            let mut arr = array![];
            for i in 0
                ..self
                    .student_to_classes
                    .entry(student)
                    .len() {
                        arr.append(self.student_to_classes.entry(student).at(i).read());
                    };
            arr
        }

        fn get_instructor_org_classes(
            self: @ContractState, org_: ContractAddress, instructor: ContractAddress
        ) -> Array<Class> {
            let mut arr = array![];
            for i in 0
                ..self
                    .org_instructor_classes
                    .entry((org_, instructor))
                    .len() {
                        arr
                            .append(
                                self.org_instructor_classes.entry((org_, instructor)).at(i).read()
                            );
                    };
            arr
        }

        // each orgnization/school should have info for instructors, & students
        fn get_org_instructors(self: @ContractState, org_: ContractAddress) -> Array<Instructor> {
            let mut arr = array![];
            for i in 0
                ..self
                    .org_to_instructors
                    .entry(org_)
                    .len() {
                        arr.append(self.org_to_instructors.entry(org_).at(i).read());
                    };
            arr
        }

        fn get_org_info(self: @ContractState, org_: ContractAddress) -> Organization {
            let mut organization_info: Organization = self.organization_info.entry(org_).read();
            organization_info
        }

        fn get_all_org_info(self: @ContractState) -> Array<Organization> {
            let mut arr = array![];
            for i in 0..self.all_org_info.len() {
                arr.append(self.all_org_info.at(i).read());
            };
            arr
        }

        fn get_student_info(self: @ContractState, student_: ContractAddress) -> Student {
            let mut student_info: Student = self.student_info.entry(student_).read();
            student_info
        }

        fn get_instructor_part_of_org(self: @ContractState, instructor: ContractAddress) -> bool {
            let creator = get_caller_address();
            let isTrue = self.instructor_part_of_org.entry((creator, instructor)).read();
            return isTrue;
        }

        fn get_instructor_info(
            self: @ContractState, instructor: ContractAddress
        ) -> Array<Instructor> {
            let mut arr = array![];
            for i in 0
                ..self
                    .instructor_key_to_info
                    .entry(instructor)
                    .len() {
                        arr.append(self.instructor_key_to_info.entry(instructor).at(i).read());
                    };
            arr
        }
        fn get_bootcamp_info(
            self: @ContractState, org_: ContractAddress, bootcamp_id: u64
        ) -> Bootcamp {
            let bootcamp: Bootcamp = self.org_to_bootcamps.entry(org_).at(bootcamp_id).read();
            bootcamp
        }
    }

    //Free functions

    fn create_a_class(
        ref self: ContractState,
        org_: ContractAddress,
        num_of_class_to_create: u256,
        bootcamp_id: u256
    ) {
        let caller = get_caller_address();
        let status: bool = self.instructor_part_of_org.entry((org_, caller)).read();
        // check if an instructor is associated to an organization
        if status {
            let class_data: Class = Class {
                address_of_org: org_,
                instructor: caller,
                num_of_reg_students: 0,
                active_status: true,
                bootcamp_id: bootcamp_id
            };
            // update the org_instructor to classes created
            self.org_instructor_classes.entry((org_, caller)).append().write(class_data);
            // update all general classes linked to org
            let mut org: Organization = self.organization_info.entry(org_).read();
            org.number_of_all_classes += num_of_class_to_create;
            self.organization_info.entry(org_).write(org);
        } else {
            panic!("not an instructor in this org");
        }
    }

    // add instructor to an organization
    fn add_instructor_to_org(
        ref self: ContractState,
        caller: ContractAddress,
        instructor: ContractAddress,
        org_name: ByteArray
    ) {
        assert(!instructor.is_zero(), 'zero address.');
        if !self.instructor_part_of_org.entry((caller, instructor)).read() {
            self.instructor_part_of_org.entry((caller, instructor)).write(true);

            let mut instructor_data: Instructor = Instructor {
                address_of_instructor: instructor,
                num_of_classes: 0,
                name_of_org: org_name.clone(),
                organization_address: caller
            };
            self.org_to_instructors.entry(caller).append().write(instructor_data);
            self
                .instructor_key_to_info
                .entry(instructor)
                .append()
                .write(
                    Instructor {
                        address_of_instructor: instructor,
                        num_of_classes: 0,
                        name_of_org: org_name,
                        organization_address: caller
                    }
                );
            let mut org_call_data: Organization = self.organization_info.entry(caller).read();
            org_call_data.number_of_instructors += 1;
            self.organization_info.entry(caller).write(org_call_data);
        } else {
            panic!("already added.");
        }
    }


    fn get_all_registration_request(self: @ContractState, org_: ContractAddress) -> Array<Student> {
        let mut arr_of_request = array![];

        for i in 0
            ..self
                .org_to_requests
                .entry(org_)
                .len() {
                    arr_of_request.append(self.org_to_requests.entry(org_).at(i).read());
                };

        arr_of_request
    }

    fn only_admin(ref self: ContractState) {
        let caller = get_caller_address();
        // assert(caller == self.admin.read(), 'Not admin');
    }
}
