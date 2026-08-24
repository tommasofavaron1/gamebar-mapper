using System;
using System.IO;
using System.Runtime.Serialization.Json;
using System.Threading.Tasks;
using WidgetSampleCS.Models;
using Windows.Storage;

namespace WidgetSampleCS.Services
{
    public sealed class ProfileStore
    {
        private const string ProfileFileName = "controller-profile.json";

        public async Task<MappingProfile> LoadAsync()
        {
            try
            {
                var file = await ApplicationData.Current.LocalFolder.GetFileAsync(ProfileFileName);
                using (var stream = await file.OpenStreamForReadAsync())
                {
                    var serializer = new DataContractJsonSerializer(typeof(MappingProfile));
                    return serializer.ReadObject(stream) as MappingProfile ?? MappingProfile.CreateDefault();
                }
            }
            catch (FileNotFoundException)
            {
                return MappingProfile.CreateDefault();
            }
            catch (IOException)
            {
                return MappingProfile.CreateDefault();
            }
            catch (System.Runtime.Serialization.SerializationException)
            {
                return MappingProfile.CreateDefault();
            }
        }

        public async Task SaveAsync(MappingProfile profile)
        {
            var file = await ApplicationData.Current.LocalFolder.CreateFileAsync(
                ProfileFileName,
                CreationCollisionOption.ReplaceExisting);

            using (var stream = await file.OpenStreamForWriteAsync())
            {
                stream.SetLength(0);
                var serializer = new DataContractJsonSerializer(typeof(MappingProfile));
                serializer.WriteObject(stream, profile);
                await stream.FlushAsync();
            }
        }
    }
}