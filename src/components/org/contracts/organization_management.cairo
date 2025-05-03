use attendsys::components::org::interfaces::IOrganizationManagement::IOrganizationManagement;
#[starknet::component]
pub mod OrganizationManagementComponent {
    use super::AttenSysOrg;
    use attendsys::components::org::types::{
        Bootcamp, Bootcampclass, Class, Instructor, Organization, RegisteredBootcamp, Student,
    };
    use starknet::storage::{
        Map, Mutable, MutableVecTrait, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    pub struct Storage {
        // organization_info: Map<ContractAddress, Organization>,
        // all_org_info: Vec<Organization>,
        // created_status: Map<ContractAddress, bool>,
        // org_to_balance_of_sponsorship: Map<ContractAddress, u256>,
        // org_to_instructors: Map<ContractAddress, Vec<Instructor>>,
        // org_to_bootcamps: Map<ContractAddress, Vec<Bootcamp>>,
        // org_to_uploaded_videos_link: Map<(ContractAddress, u64), Vec<ByteArray>>,
        // org_to_requests: Map<ContractAddress, Vec<Student>>,
        // org_suspended: Map<ContractAddress, bool>,
        // org_instructor_classes: Map<(ContractAddress, ContractAddress), Vec<Class>>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        OrganizationProfile: OrganizationProfile,
        InstructorAddedToOrg: InstructorAddedToOrg,
        InstructorRemovedFromOrg: InstructorRemovedFromOrg
        OrganizationSuspended: OrganizationSuspended
    }

    #[derive(Drop, starknet::Event)]
    pub struct OrganizationProfile {
        pub org_name: ByteArray,
        pub org_ipfs_uri: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    pub struct InstructorAddedToOrg {
        pub org_name: ByteArray,
        pub org_address: ContractAddress,
        #[key]
        pub instructor: Array<ContractAddress>,
    }

    #[derive(Drop, starknet::Event)]
    pub struct InstructorRemovedFromOrg {
        pub instructor_addr: ContractAddress,
        pub org_owner: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OrganizationSuspended {
        pub org_contract_address: ContractAddress,
        pub org_name: ByteArray,
        pub suspended: bool,
    }

    #[embeddable_as(OrganizationManagementImpl)]
    impl OrganizationManagementComponentImpl<
        TContractState, +HasComponent<TContractState>,
    > of super::IOrganizationManagement<ComponentState<TContractState>> {
        fn create_org_profile(
            ref self: ComponentState<TContractState>, org_name: ByteArray, org_ipfs_uri: ByteArray,
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
                        },
                    );
                let orginization_name = org_name.clone();

                self.emit(OrganizationProfile { org_name: orginization_name, org_ipfs_uri: uri });
                // add the organization creator as an instructor
                self.insert_instructor_to_org(ref self, creator, creator, org_name);
            } else {
                panic!("created an organization.");
            }
        }

        fn add_instructor_to_org(
            ref self: ComponentState<TContractState>,
            instructor: Array<ContractAddress>,
            org_name: ByteArray,
        ) {
            let caller = get_caller_address();
            let status: bool = self.created_status.entry(caller).read();
            // confirm that the caller is associated an organization
            if status {
                //assert organization not suspended
                assert(!self.org_suspended.entry(caller).read(), 'organization suspended');
                for i in 0..instructor.len() {
                    self
                        .insert_instructor_to_org(
                            ref self, caller, *instructor[i], org_name.clone(),
                        );
                }
                self
                    .emit(
                        InstructorAddedToOrg {
                            org_name: org_name.clone(), org_address: caller, instructor: instructor,
                        },
                    )
            } else {
                panic!("no organization created.");
            }
        }

        fn remove_instructor_from_org(
            ref self: ComponentState<TContractState>, instructor: ContractAddress,
        ) {
            assert(!instructor.is_zero(), 'zero address.');
            let caller = get_caller_address();
            let status: bool = self.created_status.entry(caller).read();
            // confirm that the caller is associated an organization
            if status {
                //assert organization not suspended
                assert(!self.org_suspended.entry(caller).read(), 'organization suspended');

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
                    for i in 0..instructors_in_org.len() {
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
                            self.org_to_instructors.entry(caller).at(i).write(lastInstructor);
                        }

                        // Event ng for removing an inspector
                        self
                            .emit(
                                InstructorRemovedFromOrg {
                                    instructor_addr: instructor, org_owner: caller,
                                },
                            )
                    }
                } else {
                    panic!("not an instructor.");
                }
            } else {
                panic!("no organization created.");
            }
        }

        fn get_all_registration_request(
            self: @ComponentState<TContractState>, org_: ContractAddress,
        ) -> Array<Student> {
            self.fetch_all_registration_request(self, org_)
        }

        fn suspend_organization(
            ref self: ComponentState<TContractState>, org_: ContractAddress, suspend: bool,
        ) {
            self.only_admin(ref self);
            let org: Organization = self.organization_info.entry(org_).read();
            assert(!org.address_of_org.is_zero(), 'Organization not created');
            if suspend {
                assert(!self.org_suspended.entry(org_).read(), 'Organization suspended');
                self.org_suspended.entry(org_).write(true);
            } else {
                assert(self.org_suspended.entry(org_).read(), 'Organization not suspended');
                self.org_suspended.entry(org_).write(false);
            }
            self
                .emit(
                    OrganizationSuspended {
                        org_contract_address: org_, org_name: org.org_name, suspended: suspend,
                    },
                );
        }

        fn get_all_org_bootcamps(
            self: @ComponentState<TContractState>, org_: ContractAddress,
        ) -> Array<Bootcamp> {
            let mut arr_of_all_created_bootcamps = array![];

            for i in 0..self.org_to_bootcamps.entry(org_).len() {
                arr_of_all_created_bootcamps.append(self.org_to_bootcamps.entry(org_).at(i).read());
            }

            arr_of_all_created_bootcamps
        }

        fn get_all_org_classes(
            self: @ComponentState<TContractState>, org_: ContractAddress,
        ) -> Array<Class> {
            let mut arr_of_org = array![];
            let mut arr_of_instructors = array![];
            let mut arr_of_all_created_classes = array![];

            for i in 0..self.all_org_info.len() {
                // let i_u32: u32 = i.try_into().unwrap();
                arr_of_org.append(self.all_org_info.at(i).read());
                let i_u32: u32 = i.try_into().unwrap();

                for j in 0
                    ..self.org_to_instructors.entry(*arr_of_org.at(i_u32).address_of_org).len() {
                    let j_u32: u32 = j.try_into().unwrap();
                    arr_of_instructors
                        .append(
                            self
                                .org_to_instructors
                                .entry(*arr_of_org.at(i_u32).address_of_org)
                                .at(j)
                                .read(),
                        );

                    for k in 0
                        ..self
                            .org_instructor_classes
                            .entry(
                                (
                                    *arr_of_org.at(i_u32).address_of_org,
                                    *arr_of_instructors.at(j_u32).address_of_instructor,
                                ),
                            )
                            .len() {
                        arr_of_all_created_classes
                            .append(
                                self
                                    .org_instructor_classes
                                    .entry(
                                        (
                                            *arr_of_org.at(i_u32).address_of_org,
                                            *arr_of_instructors.at(j_u32).address_of_instructor,
                                        ),
                                    )
                                    .at(k)
                                    .read(),
                            );
                    }
                }
            }

            arr_of_all_created_classes
        }

        fn get_instructor_org_classes(
            self: @ComponentState<TContractState>,
            org_: ContractAddress,
            instructor: ContractAddress,
        ) -> Array<Class> {
            let mut arr = array![];
            for i in 0..self.org_instructor_classes.entry((org_, instructor)).len() {
                arr.append(self.org_instructor_classes.entry((org_, instructor)).at(i).read());
            }
            arr
        }

        fn get_org_instructors(
            self: @ComponentState<TContractState>, org_: ContractAddress,
        ) -> Array<Instructor> {
            let mut arr = array![];
            for i in 0..self.org_to_instructors.entry(org_).len() {
                arr.append(self.org_to_instructors.entry(org_).at(i).read());
            }
            arr
        }

        fn get_org_info(
            self: @ComponentState<TContractState>, org_: ContractAddress,
        ) -> Organization {
            let mut organization_info: Organization = self.organization_info.entry(org_).read();
            organization_info
        }

        fn get_all_org_info(self: @ComponentState<TContractState>) -> Array<Organization> {
            let mut arr = array![];
            for i in 0..self.all_org_info.len() {
                arr.append(self.all_org_info.at(i).read());
            }
            arr
        }

        fn get_org_sponsorship_balance(
            self: @ComponentState<TContractState>, organization: ContractAddress,
        ) -> u256 {
            self.org_to_balance_of_sponsorship.entry(organization).read()
        }

        fn is_org_suspended(self: @ComponentState<TContractState>, org_: ContractAddress) -> bool {
            let is_suspended: bool = self.org_suspended.entry(org_).read();
            is_suspended
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn fetch_all_registration_request(
            self: @ComponentState<TContractState>, org_: ContractAddress,
        ) -> Array<Student> {
            let mut arr_of_request = array![];

            for i in 0..self.org_to_requests.entry(org_).len() {
                arr_of_request.append(self.org_to_requests.entry(org_).at(i).read());
            }

            arr_of_request
        }

        fn insert_instructor_to_org(
            ref self: ComponentState<TContractState>,
            caller: ContractAddress,
            instructor: ContractAddress,
            org_name: ByteArray,
        ) {
            assert(!instructor.is_zero(), 'zero address.');
            if !self.instructor_part_of_org.entry((caller, instructor)).read() {
                self.instructor_part_of_org.entry((caller, instructor)).write(true);

                let mut instructor_data: Instructor = Instructor {
                    address_of_instructor: instructor,
                    num_of_classes: 0,
                    name_of_org: org_name.clone(),
                    organization_address: caller,
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
                            organization_address: caller,
                        },
                    );
                let mut org_call_data: Organization = self.organization_info.entry(caller).read();
                org_call_data.number_of_instructors += 1;
                self.organization_info.entry(caller).write(org_call_data);
            } else {
                panic!("already added.");
            }
        }
        fn only_admin(ref self: ComponentState<TContractState>) {
            let _caller = get_caller_address();
            assert(_caller == self.admin.read(), 'Not admin');
        }
    }
}
