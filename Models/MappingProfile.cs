using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Runtime.Serialization;
using Windows.Gaming.Input;

namespace WidgetSampleCS.Models
{
    [DataContract]
    public sealed class MappingProfile
    {
        [DataMember]
        public string Name { get; set; } = "Predefinito";

        [DataMember]
        public bool Enabled { get; set; }

        [DataMember]
        public int SelectedControllerIndex { get; set; }

        [DataMember]
        public ObservableCollection<MappingEntry> Mappings { get; set; } = new ObservableCollection<MappingEntry>();

        public static MappingProfile CreateDefault()
        {
            var profile = new MappingProfile();
            foreach (var button in MappingEntry.SupportedInputs)
            {
                profile.Mappings.Add(new MappingEntry { Source = button, Target = button });
            }

            return profile;
        }

        public void EnsureSupportedMappings()
        {
            foreach (var source in MappingEntry.SupportedInputs)
            {
                if (!Mappings.Any(mapping => mapping.Source == source))
                {
                    Mappings.Add(new MappingEntry { Source = source, Target = source });
                }
            }
        }
    }

    [DataContract]
    public sealed class MappingEntry : INotifyPropertyChanged
    {
        public const string DisabledTarget = "Disabilitato";

        public static readonly IReadOnlyList<string> SupportedInputs = Array.AsReadOnly(new[]
        {
            "A", "B", "X", "Y", "DPadUp", "DPadDown", "DPadLeft", "DPadRight",
            "LeftShoulder", "RightShoulder", "LeftTrigger", "RightTrigger",
            "LeftThumbstick", "RightThumbstick", "Menu", "View"
        });

        private string target;

        [DataMember]
        public string Source { get; set; }

        [DataMember]
        public string Target
        {
            get => target;
            set
            {
                if (target == value)
                {
                    return;
                }

                target = value;
                PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(Target)));
            }
        }

        public IReadOnlyList<string> TargetOptions
        {
            get
            {
                var targets = new List<string>(SupportedInputs) { DisabledTarget };
                return targets;
            }
        }

        public event PropertyChangedEventHandler PropertyChanged;

        public bool IsPressed(GamepadReading reading)
        {
            if (Source == "LeftTrigger")
            {
                return reading.LeftTrigger > 0.1;
            }

            if (Source == "RightTrigger")
            {
                return reading.RightTrigger > 0.1;
            }

            return Enum.TryParse(Source, out GamepadButtons sourceButton)
                && (reading.Buttons & sourceButton) == sourceButton;
        }
    }
}