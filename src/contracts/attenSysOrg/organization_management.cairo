use core::starknet::{ContractAddress, get_caller_address};
use crate::base::types::{Organization, Instructor};
use crate::events::{OrganizationProfile, InstructorAddedToOrg, InstructorRemovedFromOrg, OrganizationSuspended};
use crate::storage_groups::{OrganizationStorage, InstructorStorage, SystemStorage};

#[starknet::interface]
pub trait IOrganizationManagement<TContractState> {
    fn create_org_profile(ref self: TContractState, org_name: ByteArray, org_ipfs_uri: ByteArray);
    fn add_instructor_to_org(ref self: TContractState, instructor: Array<ContractAddress>, org_name: ByteArray);
    fn remove_instructor_from_org(ref self: TContractState, instructor: ContractAddress);
    fn suspend_organization(ref self: TContractState, org_: ContractAddress, suspend: bool);
    fn get_org_info(self: @TContractState, org_: ContractAddress) -> Organization;
    fn get_all_org_info(self: @TContractState) -> Array<Organization>;
    fn get_org_instructors(self: @TContractState, org_: ContractAddress) -> Array<Instructor>;
    fn is_org_suspended(self: @TContractState, org_: ContractAddress) -> bool;
}

#[generate_trait]
pub impl OrganizationManagement of IOrganizationManagement<ContractState> {
    //ability to create organization profile, each org info should be saved properly, use
        //mappings and structs where necessary
    fn create_org_profile(ref self: ContractState, _org_name: ByteArray, _org_ipfs_uri: ByteArray) {
        let creator = get_caller_address();
        let status: bool = self.created_status.entry(creator).read();
        if !status {
            self.created_status.entry(creator).write(true);

            // create organization and update to an address
            let org_call_data: Organization = Organization {
                address_of_org: creator,
                org_name: _org_name.clone(),
                number_of_instructors: 0,
                number_of_students: 0,
                number_of_all_classes: 0,
                number_of_all_bootcamps: 0,
                org_ipfs_uri: _org_ipfs_uri.clone(),
                total_sponsorship_fund: 0,
            };

            let uri = _org_ipfs_uri.clone();

            self.all_org_info.append().write(org_call_data);
            self.organization_info.entry(creator).write(
                Organization {
                    address_of_org: creator,
                    org_name: _org_name.clone(),
                    number_of_instructors: 0,
                    number_of_students: 0,
                    number_of_all_classes: 0,
                    number_of_all_bootcamps: 0,
                    org_ipfs_uri: _org_ipfs_uri,
                    total_sponsorship_fund: 0,
                },
            );
            let orginization_name = _org_name.clone();

            self.emit(OrganizationProfile { org_name: orginization_name, org_ipfs_uri: uri });
            
            // Call the helper function to add the organization creator as an instructor
            self._add_instructor_to_org(creator, creator, _org_name);
        } else {
            panic!("already created an organization.");
        }
    }
    
    // add array of instructor to an organization
    fn add_instructor_to_org(
        ref self: ContractState, instructor: Array<ContractAddress>, _org_name: ByteArray,
    ) {
        let caller = get_caller_address();
        let status: bool = self.created_status.entry(caller).read();
        // confirm that the caller is associated an organization
        if status {
            //assert organization not suspended
            assert(!self.org_suspended.entry(caller).read(), 'organization suspended');
            for i in 0
                ..instructor
                    .len() {
                        add_instructor_to_org(
                            ref self, caller, *instructor[i], _org_name.clone()
                        );
                    };
            self
                .emit(
                    InstructorAddedToOrg { org_name: _org_name.clone(), instructor: instructor },
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

    fn suspend_organization(ref self: ContractState, org_: ContractAddress, suspend: bool) {
        only_admin(ref self);
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


    fn is_org_suspended(self: @ContractState, org_: ContractAddress) -> bool {
        let is_suspended: bool = self.org_suspended.entry(org_).read();
        is_suspended
    }

    fn add_instructor_to_org(
        ref self: ContractState,
        caller: ContractAddress,
        instructor: ContractAddress,
        _org_name: ByteArray,
    ) {
        assert(!instructor.is_zero(), 'zero address.');
        if !self.instructor_part_of_org.entry((caller, instructor)).read() {
            self.instructor_part_of_org.entry((caller, instructor)).write(true);

            let mut instructor_data: Instructor = Instructor {
                address_of_instructor: instructor,
                num_of_classes: 0,
                name_of_org: _org_name.clone(),
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
                        name_of_org: _org_name,
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


    fn get_specific_organization_registered_bootcamp(
        self: @ContractState, org: ContractAddress, student: ContractAddress
    ) -> Array<RegisteredBootcamp> {
        let mut array_of_specific_org_reg_bootcamp = array![];
        for i in 0
            ..self
                .student_address_to_specific_bootcamp
                .entry((org, student))
                .len() {
                    array_of_specific_org_reg_bootcamp
                        .append(
                            self
                                .student_address_to_specific_bootcamp
                                .entry((org, student))
                                .at(i)
                                .read()
                        );
                };
        array_of_specific_org_reg_bootcamp
    }


    fn suspend_org_bootcamp(
        ref self: ContractState, org_: ContractAddress, bootcamp_id_: u64, suspend: bool,
    ) {
        only_admin(ref self);
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


}