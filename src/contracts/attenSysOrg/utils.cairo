use core::starknet::{get_caller_address, ContractAddress};

// Common utility functions used across modules

// Access control helper for admin functions
fn only_admin(ref self: ContractState) {
    let caller = get_caller_address();
    let admin = self.admin.read();
    assert(caller == admin, 'not admin');
}

// Address validation
fn validate_address(address: ContractAddress) -> bool {
    !address.is_zero()
}

// Checks if the caller is part of the specified organization
fn is_caller_part_of_org(ref self: ContractState, org_address: ContractAddress) -> bool {
    let caller = get_caller_address();
    
    // Check if caller is the organization itself
    if caller == org_address {
        return self.created_status.entry(caller).read();
    }
    
    // Check if caller is an instructor in the organization
    self.instructor_part_of_org.entry((org_address, caller)).read()
}

// Check if bootcamp exists and is not suspended
fn validate_bootcamp(ref self: ContractState, org_address: ContractAddress, bootcamp_id: u64) -> bool {
    // First check if organization exists
    if !self.created_status.entry(org_address).read() {
        return false;
    }
    
    // Check if bootcamp exists
    if bootcamp_id >= self.org_to_bootcamps.entry(org_address).len() {
        return false;
    }
    
    // Check if bootcamp is not suspended
    !self.bootcamp_suspended.entry(org_address).entry(bootcamp_id).read()

    fn only_admin(ref self: ContractState) {
        let _caller = get_caller_address();
        assert(_caller == self.admin.read(), 'Not admin');
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
        self: @ContractState, instructor: ContractAddress,
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

    // read functions
    fn get_all_org_classes(self: @ContractState, org_: ContractAddress) -> Array<Class> {
        let mut arr_of_org = array![];
        let mut arr_of_instructors = array![];
        let mut arr_of_all_created_classes = array![];

        for i in 0
            ..self
                .all_org_info
                .len() {
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
                                            .read(),
                                    );

                                for k in 0
                                    ..self
                                        .org_instructor_classes
                                        .entry(
                                            (
                                                *arr_of_org.at(i_u32).address_of_org,
                                                *arr_of_instructors
                                                    .at(j_u32)
                                                    .address_of_instructor,
                                            ),
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
                                                                    .address_of_instructor,
                                                            ),
                                                        )
                                                        .at(k)
                                                        .read(),
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
        self: @ContractState, org_: ContractAddress, instructor: ContractAddress,
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
}