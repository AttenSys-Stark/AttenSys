//The contract
#[starknet::contract]
pub mod AttenSysOrg {
    use attendsys::components::org::contracts::admin_management::AdminManagementComponent;
    use attendsys::components::org::contracts::bootcamp_management::BootcampManagementComponent;
    use attendsys::components::org::contracts::class_management::ClassManagementComponent;
    use attendsys::components::org::contracts::instructor_management::InstructorManagementComponent;
    use attendsys::components::org::interfaces::IAttenSysOrg::IAttenSysOrg;
    use attendsys::components::org::contracts::organization_management::OrganizationManagementComponent;
    use attendsys::components::org::contracts::sponsorship_management::SponsorshipManagementComponent;
    use attendsys::components::org::contracts::student_management::StudentManagementComponent;
    use attendsys::components::org::types::{
        Bootcamp, Bootcampclass, Class, Instructor, Organization, RegisteredBootcamp, Student,
    };
    // use attendsys::contracts::AttenSysSponsor::{
    //     IAttenSysSponsorDispatcher, IAttenSysSponsorDispatcherTrait,
    // };
    use core::num::traits::Zero;
    use core::starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use core::starknet::syscalls::deploy_syscall;
    use core::starknet::{ClassHash, ContractAddress, contract_address_const, get_caller_address};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::event::EventEmitter;

    component!(
        path: AdminManagementComponent,
        storage: admin_management_storage,
        event: AdminManagementEvent,
    );
    component!(
        path: BootcampManagementComponent,
        storage: bootcamp_management_storage,
        event: BootcampManagementEvent,
    );
    component!(
        path: ClassManagementComponent,
        storage: class_management_storage,
        event: ClassManagementEvent,
    );
    component!(
        path: InstructorManagementComponent,
        storage: instructor_management_storage,
        event: InstructorManagementEvent,
    );
    component!(
        path: OrganizationManagementComponent,
        storage: organization_management_storage,
        event: OrganizationManagementEvent,
    );
    component!(
        path: SponsorshipManagementComponent,
        storage: sponsorship_management_storage,
        event: SponsorshipManagementEvent,
    );
    component!(
        path: StudentManagementComponent,
        storage: student_management_storage,
        event: StudentManagementEvent,
    );
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    /// Ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    /// Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        // save an organization profile and return info when needed.
        organization_info: Map<ContractAddress, Organization>,
        // save all organization info
        all_org_info: Vec<Organization>,
        // save all bootcamps
        all_bootcamps_created: Vec<Bootcamp>,
        // status of org creator address
        created_status: Map<ContractAddress, bool>,
        // org to balance_of_sponsorship
        org_to_balance_of_sponsorship: Map<ContractAddress, u256>,
        // save instructors of org in an array
        org_to_instructors: Map<ContractAddress, Vec<Instructor>>,
        // save bootcamps of org in an array
        org_to_bootcamps: Map<ContractAddress, Vec<Bootcamp>>,
        // org to uploaded ipfs video links
        org_to_uploaded_videos_link: Map<(ContractAddress, u64), Vec<ByteArray>>,
        //validate that an instructor is associated to an org
        instructor_part_of_org: Map<(ContractAddress, ContractAddress), bool>,
        // instructor as key
        instructor_key_to_info: Map<ContractAddress, Vec<Instructor>>,
        //maps org and instructor to classes
        org_instructor_classes: Map<(ContractAddress, ContractAddress), Vec<Class>>,
        // track the number of classes a single student has registered for.
        student_to_classes: Map<ContractAddress, Vec<Class>>,
        // update and retrieve students info
        student_info: Map<ContractAddress, Student>,
        //saves attendance status of students
        student_attendance_status: Map<(ContractAddress, u64, u64, ContractAddress), bool>,
        //saves attendance status of students
        inst_student_status: Map<ContractAddress, Map<ContractAddress, bool>>,
        //cerified course, student ---> true
        certify_student: Map<(ContractAddress, u64, ContractAddress), bool>,
        //nft classhash
        hash: ClassHash,
        // the currency used on the platform
        token_address: ContractAddress,
        // sponsorship contract address
        sponsorship_contract_address: ContractAddress,
        // AttenSys Admin
        admin: ContractAddress,
        // address of intended new admin
        intended_new_admin: ContractAddress,
        // map org to all requested registration
        org_to_requests: Map<ContractAddress, Vec<Student>>,
        // map org => suspension status
        org_suspended: Map<ContractAddress, bool>,
        // map org => bootcamp => suspension status
        bootcamp_suspended: Map<ContractAddress, Map<u64, bool>>,
        //maps student address to vec of bootcamps
        student_address_to_bootcamps: Map<ContractAddress, Vec<RegisteredBootcamp>>,
        //maps student address to org address to specific bootcamp
        student_address_to_specific_bootcamp: Map<
            (ContractAddress, ContractAddress), Vec<RegisteredBootcamp>,
        >,
        //maps org to bootcamp to classID
        bootcamp_class_data_id: Map<(ContractAddress, u64), Vec<u64>>,
        //saves all certifed student for each bootcamp
        certified_students_for_bootcamp: Map<(ContractAddress, u64), Vec<ContractAddress>>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        admin_management_storage: AdminManagementComponent::Storage,
        #[substorage(v0)]
        bootcamp_management_storage: BootcampManagementComponent::Storage,
        #[substorage(v0)]
        class_management_storage: ClassManagementComponent::Storage,
        #[substorage(v0)]
        instructor_management_storage: InstructorManagementComponent::Storage,
        #[substorage(v0)]
        organization_management_storage: OrganizationManagementComponent::Storage,
        #[substorage(v0)]
        sponsorship_management_storage: SponsorshipManagementComponent::Storage,
        #[substorage(v0)]
        student_management_storage: StudentManagementComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        class_hash: ClassHash,
        _token_address: ContractAddress,
        sponsorship_contract_address: ContractAddress,
    ) {
        self.hash.write(class_hash);
        self.token_address.write(_token_address);
        self.sponsorship_contract_address.write(sponsorship_contract_address);
        self.admin.write(admin);
        self.ownable.initializer(admin);
    }

    #[abi(embed_v0)]
    impl AdminManagementImpl =
        AdminManagementComponent::AdminManagementImpl<ContractState>;
    impl BootcampManagementImpl =
        BootcampManagementComponent::BootcampManagementImpl<ContractState>;
    impl ClassManagementImpl = ClassManagementComponent::ClassManagementImpl<ContractState>;
    impl InstructorManagementImpl =
        InstructorManagementComponent::InstructorManagementImpl<ContractState>;
    impl OrganizationManagementImpl =
        OrganizationManagementComponent::OrganizationManagementImpl<ContractState>;
    impl SponsorshipManagementImpl =
        SponsorshipManagementComponent::SponsorshipManagementImpl<ContractState>;
    impl StudentManagementImpl = StudentManagementComponent::StudentManagementImpl<ContractState>;
    impl IAttenSysOrgImpl of super::IAttenSysOrg<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();
            // Replace the class hash upgrading the contract
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {}
}
