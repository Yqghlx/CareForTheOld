using CareForTheOld.Common.Constants;
using CareForTheOld.Models.Enums;
using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Families;

public class AddFamilyMemberRequest
{
    [Required(ErrorMessage = ValidationMessages.Family.PhoneRequired)]
    public string PhoneNumber { get; set; } = string.Empty;

    [Required(ErrorMessage = ValidationMessages.Family.RoleRequired)]
    public UserRole Role { get; set; }

    [Required(ErrorMessage = ValidationMessages.Family.RelationshipRequired)]
    [StringLength(20, ErrorMessage = ValidationMessages.Family.RelationshipTooLong)]
    public string Relation { get; set; } = string.Empty;
}