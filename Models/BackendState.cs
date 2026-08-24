using System.Runtime.Serialization;

namespace WidgetSampleCS.Models
{
    [DataContract]
    public sealed class BackendState
    {
        [DataMember(Name = "state")]
        public string State { get; set; }

        [DataMember(Name = "message")]
        public string Message { get; set; }
    }
}