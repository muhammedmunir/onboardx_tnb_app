import '../models/buddy_model.dart';

List<Buddy> buddies = [
  Buddy(
    id: '1',
    name: 'Sarah Johnson',
    role: 'HR Specialist',
    department: 'HR',
    imageUrl: 'https://via.placeholder.com/150',
    isOnline: true,
    specialties: ['Benefits', 'Policies', 'Onboarding'],
    email: 'sarah.j@company.com',
    phone: '+1-555-0101',
  ),
  Buddy(
    id: '2',
    name: 'Mike Chen',
    role: 'IT Support',
    department: 'IT',
    imageUrl: 'https://via.placeholder.com/150',
    isOnline: true,
    specialties: ['Software', 'Hardware', 'Network'],
    email: 'mike.chen@company.com',
    phone: '+1-555-0102',
  ),
  Buddy(
    id: '3',
    name: 'Emily Davis',
    role: 'HR Manager',
    department: 'HR',
    imageUrl: 'https://via.placeholder.com/150',
    isOnline: false,
    specialties: ['Training', 'Development', 'Culture'],
    email: 'emily.davis@company.com',
    phone: '+1-555-0103',
  ),
];