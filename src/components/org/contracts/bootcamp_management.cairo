use attendsys::components::org::interfaces::IBootcampManagement::IBootcampManagement;
#[starknet::component]
pub mod BootcampManagementComponent {
    use super::AttenSysOrg;
    use attendsys::components::org::types::Bootcamp;
    use starknet::storage::{
        Map, Mutable, MutableVecTrait, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    pub struct Storage {
        // all_bootcamps_created: Vec<Bootcamp>,
        // bootcamp_suspended: Map<ContractAddress, Map<u64, bool>>,
        // bootcamp_class_data_id: Map<(ContractAddress, u64), Vec<u64>>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        BootCampCreated: BootCampCreated,
        ActiveMeetLinkAdded: ActiveMeetLinkAdded,
        VideoLinkUploaded: VideoLinkUploaded,
        BootcampRegistration: BootcampRegistration,
        RegistrationApproved: RegistrationApproved,
        RegistrationDeclined: RegistrationDeclined,
        StudentsCertified: StudentsCertified,
        BootCampSuspended: BootCampSuspended,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BootCampCreated {
        pub org_name: ByteArray,
        pub org_address: ContractAddress,
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
        pub bootcamp_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RegistrationApproved {
        pub student_address: ContractAddress,
        pub bootcamp_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RegistrationDeclined {
        pub student_address: ContractAddress,
        pub bootcamp_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StudentsCertified {
        pub org_address: ContractAddress,
        pub class_id: u64,
        pub student_addresses: Array<ContractAddress>,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BootCampSuspended {
        pub org_contract_address: ContractAddress,
        pub bootcamp_id: u64,
        pub bootcamp_name: ByteArray,
        pub suspended: bool,
    }

    #[embeddable_as(BootcampManagementImpl)]
    impl BootcampManagementComponentImpl<
        TContractState, +HasComponent<TContractState>,
    > of super::IBootcampManagement<ComponentState<TContractState>> {
        fn create_bootcamp(
            ref self: ComponentState<TContractState>,
            org_name: ByteArray,
            bootcamp_name: ByteArray,
            nft_name: ByteArray,
            nft_symbol: ByteArray,
            nft_uri: ByteArray,
            num_of_class_to_create: u256,
            bootcamp_ipfs_uri: ByteArray,
        ) {
            let caller = get_caller_address();
            let status: bool = self.created_status.entry(caller).read();
            // confirm that the caller is associated to an organization
            if (status) {
                //assert organization not suspended
                assert(!self.org_suspended.entry(caller).read(), 'organization suspended');
                // constructor arguments
                let mut constructor_args = array![];
                nft_uri.serialize(ref constructor_args);
                nft_name.serialize(ref constructor_args);
                nft_symbol.serialize(ref constructor_args);
                //deploy contract
                let contract_address_salt: felt252 = caller.into();
                let (deployed_contract_address, _) = deploy_syscall(
                    self.hash.read(), contract_address_salt, constructor_args.span(), false,
                )
                    .expect('failed to deploy_syscall');
                let index: u64 = self.org_to_bootcamps.entry(caller).len().into();
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
                    active_meet_link: "",
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
                            active_meet_link: "",
                        },
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
                            org_address: caller,
                            bootcamp_name: bootcamp_name,
                            nft_name: nft_name,
                            nft_symbol: nft_symbol,
                            nft_uri: nft_uri,
                            num_of_classes: num_of_class_to_create,
                            bootcamp_ipfs_uri: bootcamp_ipfs_uri,
                        },
                    );
                //create classes
                self.create_a_class(ref self, caller, num_of_class_to_create, index);
            } else {
                panic!("no organization created.");
            }
        }

        fn add_active_meet_link(
            ref self: ComponentState<TContractState>,
            meet_link: ByteArray,
            bootcamp_id: u64,
            is_instructor: bool,
            org_address: ContractAddress,
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
                assert(
                    !self.bootcamp_suspended.entry(org_address).entry(bootcamp_id).read(),
                    'Bootcamp suspended',
                );
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
                            org_address: org_address,
                        },
                    );
            } else {
                panic!("not part of organization.");
            };
        }

        fn add_uploaded_video_link(
            ref self: ComponentState<TContractState>,
            video_link: ByteArray,
            is_instructor: bool,
            org_address: ContractAddress,
            bootcamp_id: u64,
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
                assert(
                    !self.bootcamp_suspended.entry(org_address).entry(bootcamp_id).read(),
                    'Bootcamp suspended',
                );
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
                            bootcamp_id: bootcamp_id,
                        },
                    );
            } else {
                panic!("not part of organization.");
            };
        }

        fn register_for_bootcamp(
            ref self: ComponentState<TContractState>,
            org_: ContractAddress,
            bootcamp_id: u64,
            student_uri: ByteArray,
        ) {
            let caller = get_caller_address();
            let status: bool = self.created_status.entry(org_).read();
            // check org is created
            if status {
                assert(
                    !self.bootcamp_suspended.entry(org_).entry(bootcamp_id).read(),
                    'Bootcamp suspended',
                );
                let mut bootcamp = self.org_to_bootcamps.entry(org_);
                for i in 0..bootcamp.len() {
                    if i == bootcamp_id {
                        let mut student: Student = self.student_info.entry(caller).read();
                        student
                            .num_of_bootcamps_registered_for = student
                            .num_of_bootcamps_registered_for
                            + 1;
                        student.student_details_uri = student_uri.clone();
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
                                    status: 0,
                                    student_details_uri: self
                                        .student_info
                                        .entry(caller)
                                        .read()
                                        .student_details_uri,
                                },
                            );
                    }
                }

                self.emit(BootcampRegistration { org_address: org_, bootcamp_id: bootcamp_id });
            } else {
                panic!("not part of organization.");
            }
        }

        fn approve_registration(
            ref self: ComponentState<TContractState>,
            student_address: ContractAddress,
            bootcamp_id: u64,
        ) {
            let caller = get_caller_address();
            let status: bool = self.created_status.entry(caller).read();
            if status {
                for i in 0..self.org_to_requests.entry(caller).len() {
                    if self
                        .org_to_requests
                        .entry(caller)
                        .at(i)
                        .read()
                        .address_of_student == student_address {
                        let mut student = self.org_to_requests.entry(caller).at(i).read();
                        student.status = 1;
                        self.org_to_requests.entry(caller).at(i).write(student);

                        let mut the_bootcamp: Bootcamp = self
                            .org_to_bootcamps
                            .entry(caller)
                            .at(bootcamp_id)
                            .read();

                        the_bootcamp.number_of_students = the_bootcamp.number_of_students + 1;
                        self.org_to_bootcamps.entry(caller).at(bootcamp_id).write(the_bootcamp);
                        self
                            .student_address_to_specific_bootcamp
                            .entry((caller, student_address))
                            .append()
                            .write(
                                RegisteredBootcamp {
                                    address_of_org: caller,
                                    student: student_address.clone(),
                                    acceptance_status: true,
                                    bootcamp_id: bootcamp_id,
                                },
                            );
                        self
                            .student_address_to_bootcamps
                            .entry(student_address)
                            .append()
                            .write(
                                RegisteredBootcamp {
                                    address_of_org: caller,
                                    student: student_address,
                                    acceptance_status: true,
                                    bootcamp_id: bootcamp_id,
                                },
                            );
                    }
                    // update organization and instructor data
                    let mut org = self.organization_info.entry(caller).read();
                    org.number_of_students = org.number_of_students + 1;
                    self.organization_info.entry(caller).write(org);
                }

                self
                    .emit(
                        RegistrationApproved {
                            student_address: student_address, bootcamp_id: bootcamp_id,
                        },
                    );
            } else {
                panic!("no organization created.");
            }
        }

        fn decline_registration(
            ref self: ComponentState<TContractState>,
            student_address: ContractAddress,
            bootcamp_id: u64,
        ) {
            let caller = get_caller_address();
            let status: bool = self.created_status.entry(caller).read();
            if status {
                for i in 0..self.org_to_requests.entry(caller).len() {
                    if self
                        .org_to_requests
                        .entry(caller)
                        .at(i)
                        .read()
                        .address_of_student == student_address {
                        let mut student = self.org_to_requests.entry(caller).at(i).read();
                        student.status = 2;
                        self.org_to_requests.entry(caller).at(i).write(student);
                    }
                }

                self
                    .emit(
                        RegistrationDeclined {
                            student_address: student_address, bootcamp_id: bootcamp_id,
                        },
                    );
            } else {
                panic!("no organization created.");
            }
        }

        fn batch_certify_students(
            ref self: ComponentState<TContractState>, org_: ContractAddress, bootcamp_id: u64,
        ) {
            //only instructor under an organization issues certificate
            //all of the registered students with attendance
            let caller = get_caller_address();
            let is_instructor = self.instructor_part_of_org.entry((org_, caller)).read();
            let mut attendance_counter = 0;
            assert(is_instructor, 'not an instructor');

            let mut arr_of_request = array![];
            for i in 0..self.org_to_requests.entry(org_).len() {
                if self.org_to_requests.entry(org_).at(i).status.read() == 1 {
                    arr_of_request
                        .append(self.org_to_requests.entry(org_).at(i).address_of_student.read());
                }
            }
            let mut class_id_arr = array![];
            for i in 0..self.bootcamp_class_data_id.entry((org_, bootcamp_id)).len() {
                class_id_arr
                    .append(self.bootcamp_class_data_id.entry((org_, bootcamp_id)).at(i).read());
            }
            //@todo mint an nft associated to the bootcamp to each student.
            for i in 0..arr_of_request.len() {
                for k in 0..class_id_arr.len() {
                    let reg_status = self
                        .student_attendance_status
                        .entry((org_, bootcamp_id, *class_id_arr.at(k), *arr_of_request.at(i)))
                        .read();
                    if reg_status {
                        attendance_counter += 1;
                    }
                }
                let attendance_criteria = class_id_arr.len() * (1 / 2);
                if attendance_counter > attendance_criteria {
                    self
                        .certify_student
                        .entry((org_, bootcamp_id, *arr_of_request.at(i)))
                        .write(true);
                    self
                        .certified_students_for_bootcamp
                        .entry((org_, bootcamp_id))
                        .append()
                        .write(*arr_of_request.at(i));
                    attendance_counter = 0;
                };
            }
            self
                .emit(
                    StudentsCertified {
                        org_address: org_, class_id: bootcamp_id, student_addresses: arr_of_request,
                    },
                )
        }

        fn single_certify_student(
            ref self: ComponentState<TContractState>,
            org_: ContractAddress,
            bootcamp_id: u64,
            students: ContractAddress,
        ) {
            let caller = get_caller_address();
            let is_instructor = self.instructor_part_of_org.entry((org_, caller)).read();
            assert(is_instructor, 'not an instructor');
            //@todo check if student has been certified
            //@todo check if address is a registered student
            self.certify_student.entry((org_, bootcamp_id, students)).write(true);
            self
                .certified_students_for_bootcamp
                .entry((org_, bootcamp_id))
                .append()
                .write(students);
        }

        fn suspend_org_bootcamp(
            ref self: ComponentState<TContractState>,
            org_: ContractAddress,
            bootcamp_id_: u64,
            suspend: bool,
        ) {
            self.only_admin(ref self);
            let bootcamp: Bootcamp = self.org_to_bootcamps.entry(org_).at(bootcamp_id_).read();
            assert(!bootcamp.address_of_org.is_zero(), 'Invalid BootCamp');
            if suspend {
                assert(
                    !self.bootcamp_suspended.entry(org_).entry(bootcamp_id_).read(),
                    'BootCamp suspended',
                );
                self.bootcamp_suspended.entry(org_).entry(bootcamp_id_).write(true);
            } else {
                assert(
                    self.bootcamp_suspended.entry(org_).entry(bootcamp_id_).read(),
                    'BootCamp not suspended',
                );
                self.bootcamp_suspended.entry(org_).entry(bootcamp_id_).write(false);
            }
            self
                .emit(
                    BootCampSuspended {
                        org_contract_address: org_,
                        bootcamp_id: bootcamp_id_,
                        bootcamp_name: bootcamp.bootcamp_name,
                        suspended: suspend,
                    },
                );
        }

        fn get_bootcamp_active_meet_link(
            self: @ComponentState<TContractState>, org_: ContractAddress, bootcamp_id: u64,
        ) -> ByteArray {
            let bootcamp: Bootcamp = self.org_to_bootcamps.entry(org_).at(bootcamp_id).read();
            bootcamp.active_meet_link
        }

        fn get_bootcamp_uploaded_video_link(
            self: @ComponentState<TContractState>, org_: ContractAddress, bootcamp_id: u64,
        ) -> Array<ByteArray> {
            let mut arr_of_all_uploaded_bootcamps_link = array![];

            for i in 0..self.org_to_uploaded_videos_link.entry((org_, bootcamp_id)).len() {
                arr_of_all_uploaded_bootcamps_link
                    .append(
                        self.org_to_uploaded_videos_link.entry((org_, bootcamp_id)).at(i).read(),
                    );
            }
            arr_of_all_uploaded_bootcamps_link
        }

        fn get_bootcamp_info(
            self: @ComponentState<TContractState>, org_: ContractAddress, bootcamp_id: u64,
        ) -> Bootcamp {
            let bootcamp: Bootcamp = self.org_to_bootcamps.entry(org_).at(bootcamp_id).read();
            bootcamp
        }

        fn get_all_bootcamps_on_platform(self: @ComponentState<TContractState>) -> Array<Bootcamp> {
            let mut arr_of_all_created_bootcamps_on_platform = array![];

            for i in 0..self.all_bootcamps_created.len() {
                arr_of_all_created_bootcamps_on_platform
                    .append(self.all_bootcamps_created.at(i).read());
            }

            arr_of_all_created_bootcamps_on_platform
        }

        fn get_all_bootcamp_classes(
            self: @ComponentState<TContractState>, org: ContractAddress, bootcamp_id: u64,
        ) -> Array<u64> {
            let mut arr = array![];
            for i in 0..self.bootcamp_class_data_id.entry((org, bootcamp_id)).len() {
                arr.append(self.bootcamp_class_data_id.entry((org, bootcamp_id)).at(i).read());
            }
            arr
        }

        fn get_certified_student_bootcamp_address(
            self: @ComponentState<TContractState>, org: ContractAddress, bootcamp_id: u64,
        ) -> Array<ContractAddress> {
            let mut arr = array![];
            for i in 0..self.certified_students_for_bootcamp.entry((org, bootcamp_id)).len() {
                arr
                    .append(
                        self.certified_students_for_bootcamp.entry((org, bootcamp_id)).at(i).read(),
                    );
            }
            arr
        }

        fn get_bootcamp_certification_status(
            self: @ComponentState<TContractState>,
            org: ContractAddress,
            bootcamp_id: u64,
            student: ContractAddress,
        ) -> bool {
            self.certify_student.entry((org, bootcamp_id, student)).read()
        }

        fn is_bootcamp_suspended(
            self: @ComponentState<TContractState>, org_: ContractAddress, bootcamp_id: u64,
        ) -> bool {
            let is_suspended: bool = self.bootcamp_suspended.entry(org_).entry(bootcamp_id).read();
            is_suspended
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn create_a_class(
            ref self: @ComponentState<TContractState>,
            org_: ContractAddress,
            num_of_class_to_create: u256,
            bootcamp_id: u64,
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
                    bootcamp_id: bootcamp_id,
                };
                // update the org_instructor to classes created
                self.org_instructor_classes.entry((org_, caller)).append().write(class_data);
                // update all general classes linked to org
                let mut org: Organization = self.organization_info.entry(org_).read();
                org.number_of_all_classes += num_of_class_to_create;
                self.organization_info.entry(org_).write(org);

                for i in 0..num_of_class_to_create {
                    self
                        .bootcamp_class_data_id
                        .entry((org_, bootcamp_id))
                        .append()
                        .write(i.try_into().unwrap())
                }
            } else {
                panic!("not an instructor in this org");
            }
        }
        fn only_admin(ref self: ComponentState<TContractState>) {
            let _caller = get_caller_address();
            assert(_caller == self.admin.read(), 'Not admin');
        }
    }
}
