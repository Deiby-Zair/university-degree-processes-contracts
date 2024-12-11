// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract DocumentProcessMaster {
    address owner;

    mapping(string => string) private programs;
    string[] private programIds;

    mapping(address => mapping(uint8 => address[])) private associatedProcesses;
    mapping(address => mapping(address => address)) private pendingEvaluations;

    event ProgramAdded(string indexed id, string program);
    event ProgramUpdated(string indexed id, string program);
    event ProgramDeleted(string indexed id);
    event DocumentProcessCreated(
        address indexed creator,
        address indexed documentProcess
    );
    event AssociatedProcessAdded(
        address indexed owner,
        address indexed process,
        string associationName
    );
    event AssociatedProcessRemoved(
        address indexed owner,
        address indexed process
    );
    event AssignmentCreated(
        address indexed assigned,
        address multisignContract
    );
    event multisignAssignment(
        address indexed processContract,
        string phase,
        address multisignContract
    );

    constructor() {
        owner = msg.sender;
    }

    // Processes Structures

    function addProgram(string memory id, string memory program) public {
        require(bytes(program).length > 0, "Process data cannot be empty");
        require(
            bytes(programs[id]).length == 0,
            "Process with this id already exists"
        );

        programs[id] = program;
        programIds.push(id);
        emit ProgramAdded(id, program);
    }

    function updateProgram(string memory id, string memory program) public {
        require(bytes(program).length > 0, "Process data cannot be empty");
        require(bytes(programs[id]).length > 0, "Process does not exist");
        programs[id] = program;
        emit ProgramUpdated(id, program);
    }

    function deleteProgram(string memory id) public {
        require(bytes(programs[id]).length > 0, "Process does not exist");
        delete programs[id];
        for (uint i = 0; i < programIds.length; i++) {
            if (
                keccak256(abi.encodePacked(programIds[i])) ==
                keccak256(abi.encodePacked(id))
            ) {
                programIds[i] = programIds[programIds.length - 1];
                // Eliminar el último elemento
                programIds.pop();
                break;
            }
        }
        emit ProgramDeleted(id);
    }

    // Document process functions

    function createDocumentProcess(
        string memory _processName,
        string memory _initialState,
        string memory _contractProcessId,
        address[] memory _students,
        address[] memory _director,
        address[] memory _codirector
    ) public returns (address) {
        DocumentProcess newDocumentProcess = new DocumentProcess(
            _processName,
            _initialState,
            _contractProcessId,
            address(this),
            _students,
            _director,
            _codirector
        );

        emit DocumentProcessCreated(msg.sender, address(newDocumentProcess));
        return address(newDocumentProcess);
    }

    function addAssociatedProcess(
        address _owner,
        uint8 _associationType,
        string memory _associationName,
        address _processAddress
    ) public {
        require(_owner != address(0), "Invalid owner");
        for (
            uint i = 0;
            i < associatedProcesses[_owner][_associationType].length;
            i++
        ) {
            require(
                associatedProcesses[_owner][_associationType][i] !=
                    _processAddress,
                "This process has already been associated"
            );
        }
        associatedProcesses[_owner][_associationType].push(_processAddress);

        emit AssociatedProcessAdded(_owner, _processAddress, _associationName);
    }

    function addEvaluatorToPending(
        address _owner,
        address _processAddress,
        address _multisignAddress
    ) public {
        require(_owner != address(0), "Invalid owner");
        pendingEvaluations[_owner][_processAddress] = _multisignAddress;
    }

    function removeAssociatedProcess(
        address _owner,
        uint8 _associationType,
        address _processAddress
    ) public {
        for (
            uint i = 0;
            i < associatedProcesses[_owner][_associationType].length;
            i++
        ) {
            if (
                associatedProcesses[_owner][_associationType][i] ==
                _processAddress
            ) {
                associatedProcesses[_owner][_associationType][
                    i
                ] = associatedProcesses[_owner][_associationType][
                    associatedProcesses[_owner][_associationType].length - 1
                ];
                // Eliminar el último elemento
                associatedProcesses[_owner][_associationType].pop();
                emit AssociatedProcessRemoved(_owner, _processAddress);
                break;
            }
        }
    }

    function removeEvaluatorFromPending(
        address _owner,
        address _contract
    ) public {
        delete pendingEvaluations[_owner][_contract];
    }

    function createAssignment(
        address[] memory _owners,
        address _processAddress,
        uint _numConfirmationsRequired,
        string memory _state
    ) public returns (address) {
        MultiSignWallet newMultisignWallet = new MultiSignWallet(
            address(this),
            _processAddress,
            _owners,
            _numConfirmationsRequired,
            _state
        );
        emit multisignAssignment(
            _processAddress,
            _state,
            address(newMultisignWallet)
        );
        for (uint i = 0; i < _owners.length; i++) {
            address owner_address = _owners[i];
            require(owner_address != address(0), "Invalid owner");
            pendingEvaluations[owner_address][_processAddress] = address(
                newMultisignWallet
            );
            emit AssignmentCreated(owner_address, address(newMultisignWallet));
        }

        return address(newMultisignWallet);
    }

    //Get functions

    function getProgram(string memory id) public view returns (string memory) {
        return programs[id];
    }

    function getAllPrograms()
        public
        view
        returns (string[] memory, string[] memory)
    {
        string[] memory programIdsResult = new string[](programIds.length);
        string[] memory processResults = new string[](programIds.length);
        for (uint i = 0; i < programIds.length; i++) {
            programIdsResult[i] = programIds[i];
            processResults[i] = programs[programIds[i]];
        }
        return (programIdsResult, processResults);
    }

    function getAssociatedProcesses(
        address _owner,
        uint8 _associationType
    ) public view returns (address[] memory) {
        return associatedProcesses[_owner][_associationType];
    }

    function getPendingEvaluations(
        address user,
        address process
    ) public view returns (address) {
        return pendingEvaluations[user][process];
    }
}

contract DocumentProcess {
    struct Transaction {
        string phase;
        address signer;
        string state;
        string associatedLink;
        string comments;
        string date;
    }

    string private processName;
    string private contractState;
    string private contractProcessId;

    Transaction[] public transactions;
    address[] private participantAddresses;
    mapping(address => string) private participants; // Atributo de participantes

    event ParticipantAdded(address participant, string name);
    event StateChanged(address signer, string state);
    event ProcessNameChanged(address signer, string processName);
    event TransactionAdded(
        string phase,
        address indexed signer,
        string state,
        string associatedLink,
        string comments,
        string date
    );

    constructor(
        string memory _processName,
        string memory _initialState,
        string memory _contractProcessId,
        address _mainContract,
        address[] memory _students,
        address[] memory _director,
        address[] memory _codirector
    ) {
        processName = _processName;
        contractState = _initialState;
        contractProcessId = _contractProcessId;
        initializeParticipants(
            _students,
            _director,
            _codirector,
            _mainContract
        );
    }

    function initializeParticipants(
        address[] memory _students,
        address[] memory _director,
        address[] memory _codirector,
        address _mainContract
    ) public {
        for (uint i = 0; i < _students.length; i++) {
            addParticipantAssociated(
                _students[i],
                0,
                "current",
                "student",
                _mainContract
            );
        }
        for (uint i = 0; i < _director.length; i++) {
            addParticipantAssociated(
                _director[i],
                0,
                "current",
                "director",
                _mainContract
            );
        }
        for (uint i = 0; i < _codirector.length; i++) {
            addParticipantAssociated(
                _codirector[i],
                0,
                "current",
                "codirector",
                _mainContract
            );
        }
    }

    function setContractState(string memory _newState) public {
        contractState = _newState;
        emit StateChanged(msg.sender, _newState);
    }

    function setProcessName(string memory _newProcessName) public {
        processName = _newProcessName;
        emit ProcessNameChanged(msg.sender, _newProcessName);
    }

    function addParticipantAssociated(
        address _participant,
        uint8 _associationType,
        string memory _associationName,
        string memory _name,
        address _mainContract
    ) public {
        participants[_participant] = _name;
        participantAddresses.push(_participant);

        emit ParticipantAdded(_participant, _name);
        DocumentProcessMaster(_mainContract).addAssociatedProcess(
            _participant,
            _associationType,
            _associationName,
            address(this)
        );
    }

    function addTransaction(
        string memory _phase,
        string memory _state,
        string memory _associatedLink,
        string memory _comments,
        string memory _date
    ) public {
        Transaction memory newTransaction = Transaction({
            phase: _phase,
            signer: msg.sender,
            state: _state,
            associatedLink: _associatedLink,
            comments: _comments,
            date: _date
        });
        transactions.push(newTransaction);
        emit TransactionAdded(
            _phase,
            msg.sender,
            _state,
            _associatedLink,
            _comments,
            _date
        );
    }

    //Get functions

    function getProcessName() public view returns (string memory) {
        return processName;
    }

    function getContractState() public view returns (string memory) {
        return contractState;
    }

    function getContractProcessId() public view returns (string memory) {
        return contractProcessId;
    }

    function getParticipant(
        address _participant
    ) public view returns (string memory) {
        return participants[_participant];
    }

    function getAllParticipantAddresses()
        public
        view
        returns (address[] memory)
    {
        return participantAddresses;
    }

    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    function getTransaction(
        uint index
    )
        public
        view
        returns (
            string memory,
            address,
            string memory,
            string memory,
            string memory,
            string memory
        )
    {
        require(index < transactions.length, "Transaction index out of bounds");
        Transaction memory t = transactions[index];
        return (
            t.phase,
            t.signer,
            t.state,
            t.associatedLink,
            t.comments,
            t.date
        );
    }
}

contract MultiSignWallet {
    string public phase;
    address public targetContract;
    address private mainContract;

    uint public numConfirmationsRequired;
    uint private numConfirmations;

    address[] private owners;
    mapping(address => bool) public isOwner;
    mapping(address => bool) public isConfirmed;

    event Confirmation(address indexed sender);

    constructor(
        address _mainContract,
        address _contract,
        address[] memory _owners,
        uint _numConfirmationsRequired,
        string memory _phase
    ) {
        require(_owners.length > 0, "Owners required");
        require(
            _numConfirmationsRequired > 0 &&
                _numConfirmationsRequired <= _owners.length,
            "Invalid number of confirmations required"
        );

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }
        mainContract = _mainContract;
        targetContract = _contract;
        numConfirmationsRequired = _numConfirmationsRequired;
        numConfirmations = 0;
        phase = _phase;
    }

    function getAllSigners() public view returns (address[] memory) {
        return owners;
    }

    function setTargetContract(address _contractAddress) public {
        targetContract = _contractAddress;
    }

    function callChangePhase(string memory newPhase) public {
        require(
            targetContract != address(0),
            "Direccion del contrato objetivo no establecida"
        );
        DocumentProcess(targetContract).setContractState(newPhase);
    }

    function confirmTransaction(string memory newPhase) public {
        require(isOwner[msg.sender], "Not owner");
        require(!isConfirmed[msg.sender], "Transaction already confirmed");

        isConfirmed[msg.sender] = true;
        numConfirmations++;

        DocumentProcessMaster(mainContract).removeEvaluatorFromPending(
            targetContract,
            msg.sender
        );
        emit Confirmation(msg.sender);

        if (numConfirmations >= numConfirmationsRequired) {
            callChangePhase(newPhase);
        }
    }
}
