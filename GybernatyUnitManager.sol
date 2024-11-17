 // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

// Контракт GybernatyUnitManager для управления уровнями пользователей
contract GybernatyUnitManager {
    // Структура для хранения информации о пользователях
    struct User {
        // Адрес пользователя
        address userAddress;
        // Флаг, указывающий, отмечен ли пользователь для повышения уровня
        bool markedUp;
        // Флаг, указывающий, отмечен ли пользователь для понижения уровня
        bool markedDown;
        // Текущий уровень пользователя
        uint32 level;
    }

    // Максимальный уровень пользователя (константа)
    uint32 public constant maxLevel = 4;
    // Количество Gbr токенов, необходимое для вступления в категорию Gybernaty
    uint256 public constant GbrTokenAmount = 1_000_000_000_000;
    // Адрес контракта Gbr токенов
    address public constant GbrTokenAddress = 0xA970cAE9Fa1D7Cca913b7C19DF45BF33d55384A9;

    // Маппинг для хранения информации о пользователях по их адресам
    mapping (address => User) public users;
    // Маппинг для хранения адресов, входящих в категорию Gybernaty
    mapping (address => bool) public gybernaties;

    // События контракта
    event UserMarkUp(address userAddress);
    event UserMarkDown(address userAddress);
    event UserLevelUp(address userAddress);
    event UserLevelDown(address userAddress);
    event GybernatyJoined(address gybernatyAddress);

    // Ошибки контракта
    error OnlyGybernaty();
    error LevelInvalid();
    error UserExists();
    error UserNotFound();
    error UserNotMarked();
    error MinLevel();
    error MaxLevel();
    error InsufficientFunds();

    // Модификатор для проверки, является ли вызывающий адрес членом категории Gybernaty
    modifier onlyGybernaty() {
        if (!gybernaties[msg.sender]) {
            revert OnlyGybernaty();
        }
        _;
    }

    // Конструктор контракта
    constructor() {
        // Контракт не имеет прав только владельца (onlyOwner)
    }

    /**
     * Функция для вступления в категорию Gybernaty
     * @dev Адрес, отправивший достаточное количество Gbr токенов, становится членом Gybernaty
     */
    function joinGybernaty() public payable onlyGybernaty {
        // Проверяем, отправлено ли достаточное количество Gbr токенов
        if (msg.value < GbrTokenAmount) {
            revert InsufficientFunds();
        }

        // Добавляем адрес в категорию Gybernaty
        gybernaties[msg.sender] = true;

        // Вызываем событие о вступлении в категорию Gybernaty
        emit GybernatyJoined(msg.sender);
    }

    /**
     * Функция для создания нового пользователя
     * @param userAddress Адрес пользователя
     * @param level Начальный уровень пользователя
     * @dev Только члены Gybernaty могут создавать новых пользователей
     */
    function createUser(address userAddress, uint32 level) public onlyGybernaty {
        // Проверяем, существует ли пользователь
        if (users[userAddress].userAddress != address(0)) {
            revert UserExists();
        }

        // Проверяем, является ли указанный уровень действительным
        if (level < 1 || level > maxLevel) {
            revert LevelInvalid();
        }

        // Создаем нового пользователя
        User memory user = User(
            userAddress,
            false,
            false,
            level
        );

        // Добавляем пользователя в маппинг
        users[userAddress] = user;

        // Вызываем событие о создании пользователя и повышении уровня
        emit UserLevelUp(userAddress);
    }

    /**
     * Функция для отметки пользователя для повышения уровня
     * @dev Пользователи могут отмечать себя для повышения уровня
     */
    function userMarkUp() public {
        address userAddress = msg.sender;

        // Проверяем, существует ли пользователь
        if (users[userAddress].userAddress == address(0)) {
            revert UserExists(); // Пользователь уже существует, поэтому не может отмечать себя повторно
        }

        // Проверяем, имеет ли пользователь максимальный уровень
        if (users[userAddress].level == maxLevel) {
            revert MaxLevel();
        }

        // Отмечаем пользователя для повышения уровня
        User memory user = User(
            userAddress,
            true,
            false,
            0
        );

        // Обновляем информацию о пользователе
        users[userAddress] = user;

        // Вызываем событие об отметке для повышения уровня
        emit UserMarkUp(userAddress);
    }

    /**
     * Функция для отметки пользователя для понижения уровня
     * @param userAddress Адрес пользователя
     * @dev Только члены Gybernaty могут отмечать пользователей для понижения уровня
     */
    function userMarkDown(address userAddress) public onlyGybernaty {
        // Проверяем, существует ли пользователь
        if (users[userAddress].userAddress == address(0)) {
            revert UserNotFound();
        }

        // Проверяем, имеет ли пользователь минимальный уровень
        if (users[userAddress].level == 1) {
            revert MinLevel();
        }

        // Отмечаем пользователя для понижения уровня
        users[userAddress].markedDown = true;

        // Вызываем событие об отметке для понижения уровня
        emit UserMarkDown(userAddress);
    }

    /**
     * Функция для повышения уровня пользователя
     * @param userAddress Адрес пользователя
     * @dev Только члены Gybernaty могут повышать уровень пользователей
     */
    function userLevelUp(address userAddress) public onlyGybernaty {
        // Проверяем, существует ли пользователь
        if (users[userAddress].userAddress == address(0)) {
            revert UserNotFound();
        }

        // Проверяем, отмечен ли пользователь для повышения уровня
        if (!users[userAddress].markedUp) {
            revert UserNotMarked();
        }

        // Повышаем уровень пользователя
        users[userAddress].level += 1;

        // Сброс отметок пользователя
        users[userAddress].markedUp = false;
        users[userAddress].markedDown = false;

        // Вызываем событие о повышении уровня
        emit UserLevelUp(userAddress);
    }

    /**
     * Функция для понижения уровня пользователя
     * @param userAddress Адрес пользователя
     * @dev Только члены Gybernaty могут понижать уровень пользователей
     */
    function userLevelDown(address userAddress) public onlyGybernaty {
        // Проверяем, существует ли пользователь
        if (users[userAddress].userAddress == address(0)) {
            revert UserNotFound();
        }

        // Проверяем, отмечен ли пользователь для понижения уровня
        if (!users[userAddress].markedDown) {
            revert UserNotMarked();
        }

        // Понижаем уровень пользователя
        users[userAddress].level -= 1;

        // Сброс отметок пользователя
        users[userAddress].markedUp = false;
        users[userAddress].markedDown = false;

        // Вызываем событие о понижении уровня
        emit UserLevelDown(userAddress);
    }

    /**
     * Функция для вывода Gbr токенов с контракта
     * @param amount Количество Gbr токенов для вывода
     * @dev Только члены Gybernaty могут выводить Gbr токены
     */
    function withdrawGbrTokens(uint256 amount) public onlyGybernaty {
        // Выводим Gbr токены на адрес вызывающего
        payable(msg.sender).transfer(amount);
    }

    /**
     * Функция для приема Gbr токенов
     * @dev Отклоняет любые другие токены, кроме Gbr токенов
     */
    receive() external payable {
        // Проверяем, является ли отправитель адресом контракта Gbr токенов
        if (msg.sender != GbrTokenAddress) {
            revert(); // Отклонить любые другие токены
        }
    }
}