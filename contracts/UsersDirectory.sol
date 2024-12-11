// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract UsersDirectory {
    struct User {
        address walletAddress;
        string email;
        string name;
        string role;
    }

    mapping(address => User) private users;
    mapping(string => address) private emailToAddress;

    event UserAdded(address indexed walletAddress, string email);
    event UserDeleted(address indexed walletAddress);
    event UserNameChanged(address indexed walletAddress, string name);
    event UserRoleChanged(address indexed walletAddress, string role);

    function getUserByWallet(
        address _walletAddress
    ) public view returns (string memory) {
        return users[_walletAddress].email;
    }

    function getUserByEmail(
        string memory _email
    ) public view returns (address) {
        return emailToAddress[_email];
    }

    function getFullUser(
        address _walletAddress
    ) public view returns (string memory, string memory, string memory) {
        return (
            users[_walletAddress].email,
            users[_walletAddress].name,
            users[_walletAddress].role
        );
    }

    function addUser(
        address _walletAddress,
        string memory _email,
        string memory _name,
        string memory _role
    ) public {
        require(_walletAddress != address(0), "Invalid wallet address");
        require(bytes(_email).length > 0, "Email cannot be empty");
        require(
            users[_walletAddress].walletAddress == address(0),
            "User already exists"
        );
        users[_walletAddress] = User({
            walletAddress: _walletAddress,
            email: _email,
            name: _name,
            role: _role
        });
        emailToAddress[_email] = _walletAddress;

        emit UserAdded(_walletAddress, _email);
    }

    function deleteUser(address _owner) public {
        require(
            users[_owner].walletAddress != address(0),
            "User does not exist"
        );
        string memory email = getUserByWallet(_owner);
        delete users[_owner];
        delete emailToAddress[email];

        emit UserDeleted(_owner);
    }

    function setUserName(address _walletAddress, string memory _name) public {
        users[_walletAddress].name = _name;
        emit UserNameChanged(_walletAddress, _name);
    }

    function setUserRole(address _walletAddress, string memory _role) public {
        users[_walletAddress].role = _role;
        emit UserRoleChanged(_walletAddress, _role);
    }
}
