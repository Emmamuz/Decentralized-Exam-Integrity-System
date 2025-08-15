# 🎓 Decentralized Exam Integrity System

A blockchain-based smart contract system for creating, managing, and validating academic exams with built-in integrity verification and anti-cheating measures.

## 📋 Overview

This Clarity smart contract provides a comprehensive solution for conducting secure digital examinations on the Stacks blockchain. It ensures exam integrity through cryptographic hash proofs, time-bound submissions, and decentralized verification mechanisms.

## ✨ Features

- 📝 **Exam Creation**: Create exams with customizable parameters
- 🔐 **Hash-based Security**: Questions and answers secured with cryptographic hashes
- ⏰ **Time-bound Sessions**: Automatic exam scheduling with block-based timing
- 👥 **Student Registration**: Secure registration system for exam participants
- 🛡️ **Anti-cheating**: Built-in cheating detection and reporting mechanisms
- 📊 **Automated Grading**: Score tracking and pass/fail determination
- 🔍 **Audit Trail**: Complete transparency of all exam activities

## 🚀 Contract Functions

### 📚 Exam Management

#### `create-exam`
Create a new exam with specified parameters.
```clarity
(create-exam 
  title 
  description 
  questions-hash 
  start-block 
  duration-blocks 
  max-attempts 
  passing-score)
```

#### `deactivate-exam`
Deactivate an existing exam (creator only).
```clarity
(deactivate-exam exam-id)
```

### 👨‍🎓 Student Operations

#### `register-for-exam`
Register to participate in an exam.
```clarity
(register-for-exam exam-id)
```

#### `submit-exam`
Submit exam answers with integrity proof.
```clarity
(submit-exam exam-id answers-hash integrity-proof)
```

### 📊 Grading & Verification

#### `grade-submission`
Grade a student's submission (creator only).
```clarity
(grade-submission exam-id student attempt score)
```

#### `report-cheating`
Report suspected cheating with evidence.
```clarity
(report-cheating exam-id student evidence-hash)
```

#### `verify-cheating-report`
Verify cheating reports (creator only).
```clarity
(verify-cheating-report exam-id student is-verified)
```

### 🔍 Read-only Functions

- `get-exam`: Retrieve exam details
- `get-registration`: Check student registration status
- `get-submission`: View submission details
- `get-result`: Get exam results for a student
- `is-exam-active`: Check if exam is currently active
- `can-submit`: Verify if student can submit
- `get-total-stats`: Get system-wide statistics

## 🛠️ Usage Instructions

### Prerequisites
- [Clarinet](https://docs.hiro.so/stacks/clarinet) installed
- Stacks wallet for testing

### 🏃‍♂️ Quick Start

1. **Clone and Setup**
   ```bash
   git clone <repository-url>
   cd Decentralized-Exam-Integrity-System
   clarinet check
   ```

2. **Create an Exam**
   ```bash
   clarinet console
   ```
   ```clarity
   (contract-call? .Decentralized-Exam-Intergrity create-exam 
     "Math Final Exam" 
     "Comprehensive mathematics examination" 
     0x1234567890abcdef1234567890abcdef12345678 
     u1000 
     u144 
     u3 
     u70)
   ```

3. **Register for Exam**
   ```clarity
   (contract-call? .Decentralized-Exam-Intergrity register-for-exam u1)
   ```

4. **Submit Answers**
   ```clarity
   (contract-call? .Decentralized-Exam-Intergrity submit-exam 
     u1 
     0xabcdef1234567890abcdef1234567890abcdef12 
     0x9876543210fedcba9876543210fedcba98765432)
   ```

### 🧪 Testing

Run the test suite:
```bash
npm install
npm test
```

## 📐 System Architecture

The contract uses several key data structures:

- **Exams Map**: Stores exam configurations and metadata
- **Registrations Map**: Tracks student enrollments
- **Submissions Map**: Records answer submissions with integrity proofs
- **Results Map**: Maintains scoring and pass/fail status
- **Cheating Reports**: Handles academic integrity violations

## 🔒 Security Features

- 🔐 **Hash Verification**: All questions and answers are cryptographically secured
- ⏱️ **Time Constraints**: Block-based timing prevents submission outside exam windows
- 👮‍♀️ **Access Control**: Role-based permissions for creators vs. students
- 🚨 **Cheating Detection**: Community-driven reporting with verification workflow
- 📝 **Immutable Records**: All activities permanently recorded on blockchain

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Clarity](https://clarity-lang.org/) smart contract language
- Deployed on [Stacks](https://stacks.co/) blockchain
- Powered by [Clarinet](https://docs.hiro.so/stacks/clarinet) development framework

---

*Securing academic integrity through blockchain technology* 🎯
