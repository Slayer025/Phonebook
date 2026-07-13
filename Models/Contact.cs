using System;
using System.ComponentModel.DataAnnotations;

namespace PhonebookApp.Models
{
    public class Contact
    {
        public int Id { get; set; }

        [Required(ErrorMessage = "Name is required.")]
        [StringLength(255, ErrorMessage = "Name cannot exceed 255 characters.")]
        public string Name { get; set; }

        [Required(ErrorMessage = "Phone number is required.")]
        [StringLength(50, ErrorMessage = "Phone number cannot exceed 50 characters.")]
        [RegularExpression(@"^[0-9+\-\s()]+$", ErrorMessage = "Phone number contains invalid characters.")]
        public string PhoneNumber { get; set; }

        [EmailAddress(ErrorMessage = "Invalid email address.")]
        [StringLength(255, ErrorMessage = "Email cannot exceed 255 characters.")]
        public string Email { get; set; }

        [StringLength(4000, ErrorMessage = "Address cannot exceed 4000 characters.")]
        public string Address { get; set; }

        public DateTime CreatedAt { get; set; }
    }
}
