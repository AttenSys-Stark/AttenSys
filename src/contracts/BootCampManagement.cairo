use core::starknet::{ContractAddress};

pub mod OrganizationManagement {
    use crate::base::types{
        Organization, Bootcamp, Instructor, Class, Student, RegisteredBootcamp, Bootcampclass
    };

    use core::starknet::{
        ContractAddress, syscalls::deploy_syscall,
        contract_address_const,
    };


    // Must make the admin an instructor to successfully call this
   pub fn create_bootcamp(
        ref self: ContractState,
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
                        bootcamp_name: bootcamp_name,
                        nft_name: nft_name,
                        nft_symbol: nft_symbol,
                        nft_uri: nft_uri,
                        num_of_classes: num_of_class_to_create,
                        bootcamp_ipfs_uri: bootcamp_ipfs_uri,
                    },
                );
            //create classes
            create_a_class(ref self, caller, num_of_class_to_create, index);
        } else {
            panic!("no organization created.");
        }
    }


    pub  fn register_for_bootcamp(
        ref self: ContractState,
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
            for i in 0
                ..bootcamp
                    .len() {
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
                    };

            self.emit(BootcampRegistration { org_address: org_, bootcamp_id: bootcamp_id });
        } else {
            panic!("not part of organization.");
        }
    }



   pub fn approve_registration(
        ref self: ContractState, student_address: ContractAddress, bootcamp_id: u64,
    ) {
        let caller = get_caller_address();
        let status: bool = self.created_status.entry(caller).read();
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
                            student.status = 1;
                            self.org_to_requests.entry(caller).at(i).write(student);

                            let mut the_bootcamp: Bootcamp = self
                                .org_to_bootcamps
                                .entry(caller)
                                .at(bootcamp_id)
                                .read();

                            the_bootcamp.number_of_students = the_bootcamp.number_of_students
                                + 1;
                            self
                                .org_to_bootcamps
                                .entry(caller)
                                .at(bootcamp_id)
                                .write(the_bootcamp);
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
                    };

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

   pub fn decline_registration(
        ref self: ContractState, student_address: ContractAddress, bootcamp_id: u64,
    ) {
        let caller = get_caller_address();
        let status: bool = self.created_status.entry(caller).read();
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
                            student.status = 2;
                            self.org_to_requests.entry(caller).at(i).write(student);
                        }
                    };

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


   pub fn mark_attendance_for_a_class(
        ref self: ContractState,
        org_: ContractAddress,
        instructor_: ContractAddress,
        class_id: u64,
        bootcamp_id: u64,
    ) {
        let caller = get_caller_address();
        let class_id_len = self.bootcamp_class_data_id.entry((org_, bootcamp_id)).len();
        assert(class_id < class_id_len && class_id >= 0, 'invalid class id');
        let mut instructor_class = self
            .org_instructor_classes
            .entry((org_, instructor_))
            .at(class_id)
            .read();
        let reg_status = self
            .student_attendance_status
            .entry((caller, bootcamp_id, class_id, caller))
            .read();
        assert(instructor_class.active_status, 'not a class');
        assert(!reg_status, 'attendance marked');
        self.student_attendance_status.entry((org_, bootcamp_id, class_id, caller)).write(true);
        self
            .emit(
                AttendanceMarked {
                    org_address: org_, instructor_address: instructor_, class_id: class_id,
                },
            );
    }


   pub fn get_all_registration_request(
        self: @ContractState, org_: ContractAddress,
    ) -> Array<Student> {
        ge
        
        pub fn get_bootcamp_active_meet_link(
            self: @ContractState, org_: ContractAddress, bootcamp_id: u64,
        ) -> ByteArray {
            let bootcamp: Bootcamp = self.org_to_bootcamps.entry(org_).at(bootcamp_id).read();
            bootcamp.active_meet_link
        }


     pub   fn get_bootcamp_uploaded_video_link(
            self: @ContractState, org_: ContractAddress, bootcamp_id: u64,
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
                                    .read(),
                            );
                    };
            arr_of_all_uploaded_bootcamps_link
        }t_all_registration_request(self, org_)
    }

     // read functions
     pub fn get_all_bootcamps_on_platform(self: @ContractState) -> Array<Bootcamp> {
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

    pub fn get_bootcamp_info(
        self: @ContractState, org_: ContractAddress, bootcamp_id: u64,
    ) -> Bootcamp {
        let bootcamp: Bootcamp = self.org_to_bootcamps.entry(org_).at(bootcamp_id).read();
        bootcamp
    }



   pub fn is_bootcamp_suspended(
        self: @ContractState, org_: ContractAddress, bootcamp_id: u64,
    ) -> bool {
        let is_suspended: bool = self.bootcamp_suspended.entry(org_).entry(bootcamp_id).read();
        is_suspended
    }

   pub fn get_registered_bootcamp(
        self: @ContractState, student: ContractAddress
    ) -> Array<RegisteredBootcamp> {
        let mut array_of_reg_bootcamp = array![];
        for i in 0
            ..self
                .student_address_to_bootcamps
                .entry(student)
                .len() {
                    array_of_reg_bootcamp
                        .append(self.student_address_to_bootcamps.entry(student).at(i).read());
                };
        array_of_reg_bootcamp
    }


   pub fn get_all_bootcamp_classes(
        self: @ContractState, org: ContractAddress, bootcamp_id: u64
    ) -> Array<u64> {
        let mut arr = array![];
        for i in 0
            ..self
                .bootcamp_class_data_id
                .entry((org, bootcamp_id))
                .len() {
                    arr
                        .append(
                            self.bootcamp_class_data_id.entry((org, bootcamp_id)).at(i).read()
                        );
                };
        arr
    }
    pub fn get_certified_student_bootcamp_address(
        self: @ContractState, org: ContractAddress, bootcamp_id: u64
    ) -> Array<ContractAddress> {
        let mut arr = array![];
        for i in 0
            ..self
                .certified_students_for_bootcamp
                .entry((org, bootcamp_id))
                .len() {
                    arr
                        .append(
                            self
                                .certified_students_for_bootcamp
                                .entry((org, bootcamp_id))
                                .at(i)
                                .read()
                        );
                };
        arr
    }
    pub fn get_bootcamp_certification_status(
        self: @ContractState, org: ContractAddress, bootcamp_id: u64, student: ContractAddress
    ) -> bool {
        self.certify_student.entry((org, bootcamp_id, student)).read()
    }


}
