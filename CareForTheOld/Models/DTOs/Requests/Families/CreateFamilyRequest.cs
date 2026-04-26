using CareForTheOld.Common.Constants;
using System.ComponentModel.DataAnnotations;

namespace CareForTheOld.Models.DTOs.Requests.Families;

public class CreateFamilyRequest
{
    [Required(ErrorMessage = ValidationMessages.Family.NameRequired)]
    [StringLength(100, ErrorMessage = ValidationMessages.NeighborCircle.NameTooLong)]
    public string FamilyName { get; set; } = string.Empty;
}